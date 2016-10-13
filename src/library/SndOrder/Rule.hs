{-# OPTIONS_GHC -fno-warn-orphans #-}

module SndOrder.Rule (
    SndOrderRule
  , addMinimalSafetyNacs
  , applySndOrderRule
  , applySecondOrder
  , newNacsPairL
  ) where

import           Data.Maybe           (mapMaybe,fromMaybe)

import           Abstract.Valid

import           Abstract.AdhesiveHLR
import           Abstract.DPO
import           Graph.Graph          as G
import           SndOrder.Morphism    as SO
import           TypedGraph.Graph
import           TypedGraph.GraphRule
import           TypedGraph.Morphism

-- | A second order rule:
--
-- @
--         nl       nr
--     NL◀─────\<NK\>─────▶NR
--      ▲        ▲        ▲
--   nacL\\    nacK\\    nacR\\
--        \\        \\        \\
--         \\   ll   \\   lr   \\
--         LL◀─────\<LK\>─────▶LR
--         ▲        ▲        ▲
--    leftL│   leftK│   leftR│
--         │        │        │
--         │    kl  │    kr  │
--         KL◀─────\<KK\>─────▶KR
--         │        │        │
--   rightL│  rightK│  rightR│
--         │        │        │
--         ▼    rl  ▼    rr  ▼
--         RL◀─────\<RK\>─────▶RR
-- @
--
-- domain rule = (ll,lr)
--
-- interface rule = (kl,kr)
--
-- codomain rule (rl,rr)
--
-- nac rule = (nl,nr)
--
-- nacs = set of: domain rule, nac rule, nacL, nacK, nacR
--
-- left = domain rule, interface rule, leftL, leftK, leftR
--
-- right = interface rule, codomain rule, rightL, rightK, rightR
type SndOrderRule a b = Production (RuleMorphism a b)

-- | Receives a function that works with a second order and a first order rule.
-- Apply this function on all possible combinations of rules.
applySecondOrder ::
     ((String, SndOrderRule a b) -> (String, GraphRule a b) -> [t])
  -> [(String, GraphRule a b)] -> [(String, SndOrderRule a b)] -> [t]
applySecondOrder f fstRules = concatMap (\r -> applySecondOrderListRules f r fstRules)

applySecondOrderListRules ::
    ((String, SndOrderRule a b) -> (String, GraphRule a b) -> [t])
 -> (String, SndOrderRule a b) -> [(String, GraphRule a b)] -> [t]
applySecondOrderListRules f sndRule = concatMap (f sndRule)

instance DPO (RuleMorphism a b) where
  invertProduction conf r = addMinimalSafetyNacs conf newRule
    where
      newRule = buildProduction (getRHS r) (getLHS r) (concatMap (shiftNacOverProduction conf r) (getNACs r))

  -- | Needs the satisfiesNACs extra verification because not every satisfiesGluingConditions nac can be shifted
  shiftNacOverProduction conf rule n =
    [calculateComatch n rule |
      satisfiesGluingConditions conf rule n &&
      satisfiesNACs conf ruleWithOnlyMinimalSafetyNacs n]

    where
      ruleWithOnlyMinimalSafetyNacs = buildProduction (getLHS rule) (getRHS rule) (minimalSafetyNacs rule)

  isPartiallyMonomorphic m l =
    isPartiallyMonomorphic (mappingLeft m)      (mappingLeft l)      &&
    isPartiallyMonomorphic (mappingInterface m) (mappingInterface l) &&
    isPartiallyMonomorphic (mappingRight m)     (mappingRight l)

applySndOrderRule :: DPOConfig -> (String, SndOrderRule a b) -> (String, GraphRule a b) -> [(String, GraphRule a b)]
applySndOrderRule conf (sndName,sndRule) (fstName,fstRule) =
  let
    matches =
      findApplicableMatches conf sndRule fstRule

    newRules =
      map (`rewrite` sndRule) matches

    newNames =
      map (\number -> fstName ++ "_" ++ sndName ++ "_" ++ show number) ([0..] :: [Int])
  in
    zip newNames newRules

-- *** Minimal Safety Nacs

-- | Adds the minimal safety nacs needed to this production always produce a second order rule.
-- If the nacs to be added not satisfies the others nacs, then it do not need to be added.
addMinimalSafetyNacs :: DPOConfig -> SndOrderRule a b -> SndOrderRule a b
addMinimalSafetyNacs nacInj sndRule =
  buildProduction
    (getLHS sndRule)
    (getRHS sndRule)
    (getNACs sndRule ++
     filter (satisfiesNACs nacInj sndRule) (minimalSafetyNacs sndRule))

data Side = LeftSide | RightSide

-- | Generates the minimal safety NACs of a 2-rule.
-- probL and probR done, pairL and pairR to do.
minimalSafetyNacs :: SndOrderRule a b -> [RuleMorphism a b]
minimalSafetyNacs sndRule =
  newNacsProb LeftSide sndRule ++
  newNacsProb RightSide sndRule ++
  newNacsPairL sndRule

newNacsProb :: Side -> SndOrderRule a b -> [SO.RuleMorphism a b]
newNacsProb side sndRule = nacNodes ++ nacEdges
  where
    (mapSide, getSide) =
      case side of
        LeftSide  -> (SO.mappingLeft, getLHS)
        RightSide -> (SO.mappingRight, getRHS)

    applyNode = applyNodeUnsafe
    applyEdge = applyEdgeUnsafe

    ruleL = codomain (getLHS sndRule)
    ruleK = domain (getLHS sndRule)
    ruleR = codomain (getRHS sndRule)

    f = mapSide (getLHS sndRule)
    g = mapSide (getRHS sndRule)

    sa = getSide ruleL
    sb = getSide ruleK
    sc = getSide ruleR

    nodeProb = [applyNode f n |
                 n <- nodesFromCodomain sb
               , isOrphanNode sa (applyNode f n)
               , isOrphanNode sb n
               , not (isOrphanNode sc (applyNode g n))]

    edgeProb = [applyEdge f n |
                 n <- edgesFromCodomain sb
               , isOrphanEdge sa (applyEdge f n)
               , isOrphanEdge sb n
               , not (isOrphanEdge sc (applyEdge g n))]

    nacNodes = map (createNacProb side ruleL . Left) nodeProb
    nacEdges = map (createNacProb side ruleL . Right) edgeProb

createNacProb :: Side -> GraphRule a b -> Either NodeId EdgeId -> SO.RuleMorphism a b
createNacProb sideChoose ruleL x = SO.ruleMorphism ruleL nacRule mapL mapK mapR
  where
    
    l = getLHS ruleL
    r = getRHS ruleL

    graphL = codomain l
    graphK = domain l
    graphR = codomain r

    (graphSide, otherSideGraph, side, otherSide) =
      case sideChoose of
        LeftSide  -> (graphR, graphL, l, r)
        RightSide -> (graphL, graphR, r, l)

    src = G.sourceOfUnsafe (domain graphSide)
    tgt = G.targetOfUnsafe (domain graphSide)

    tpNode = getNodeType otherSideGraph
    tpEdge = getEdgeType otherSideGraph

    typeSrc x = getNodeType graphSide (src x)
    typeTgt x = getNodeType graphSide (tgt x)

    n' = head (newNodes (domain graphK))
    n'' = head (newNodes (domain graphSide))

    e' = head (newEdges (domain graphK))
    e'' = head (newEdges (domain graphSide))

    newNodesK = newNodes (domain graphK)
    newNodesSide = newNodes (domain graphSide)

    invertSide = invert side

    srcInK x = fromMaybe (newNodesK !! 0) (applyNode invertSide (src x))
    tgtInK x = fromMaybe (newNodesK !! 1) (applyNode invertSide (tgt x))
    srcInR x = fromMaybe (newNodesSide !! 0) (applyNode otherSide (srcInK x))
    tgtInR x = fromMaybe (newNodesSide !! 1) (applyNode otherSide (tgtInK x))

    (updateLeft, updateRight) =
      (case x of
         (Left n) -> createNodes n n' n'' (tpNode n)
         (Right e) -> createEdges e e' e'' (tpEdge e)
                        (src e) (typeSrc e) (srcInK e) (srcInR e)
                        (tgt e) (typeTgt e) (tgtInK e) (tgtInR e))
        side otherSide
    
    nacRule = buildProduction updateLeft updateRight []
    mapL = idMap graphL (codomain updateLeft)
    mapK = idMap graphK (domain updateLeft)
    mapR = idMap graphR (codomain updateRight)

    createNodes x x' x'' tp side otherSide = 
      case sideChoose of
        LeftSide -> (updateSide1, updateSide2Map)
        RightSide -> (updateSide2Map, updateSide1)
      where
        updateSide1 = createNodeOnDomain x' tp x side
        updateSide2Cod = createNodeOnCodomain x'' tp otherSide
        updateSide2Map = updateNodeRelation x' x'' tp updateSide2Cod

    createEdges x x' x'' tp
        src typeSrc srcInK srcInR
        tgt typeTgt tgtInK tgtInR
        side otherSide =
      case sideChoose of
        LeftSide -> (updateLeftEdge, updateRightMap)
        RightSide -> (updateRightMap, updateLeftEdge)
      where
        srcRight = createNodeOnCodomain srcInR typeSrc otherSide
        tgtRight = createNodeOnCodomain tgtInR typeTgt srcRight
        updateRight = createNodeOnDomain srcInK typeSrc srcInR tgtRight
        updateRight2 = createNodeOnDomain tgtInK typeTgt tgtInR updateRight
        updateRightCod = createEdgeOnCodomain x'' srcInR tgtInR tp updateRight2
        updateRightMap = createEdgeOnDomain x' srcInK tgtInK tp x'' updateRightCod

        updateLeft = createNodeOnDomain srcInK typeSrc src side
        updateLeft2 = createNodeOnDomain tgtInK typeTgt tgt updateLeft
        updateLeftEdge = createEdgeOnDomain x' srcInK tgtInK tp x updateLeft2

newNacsPairL :: SndOrderRule a b -> [SO.RuleMorphism a b]
newNacsPairL sndRule = mapMaybe createNac ret
  where
    apply = applyNodeUnsafe
    
    ruleL = codomain (getLHS sndRule)
    ruleK = domain (getLHS sndRule)
    ruleR = codomain (getRHS sndRule)
    
    fl = SO.mappingLeft (getLHS sndRule)
    gl = SO.mappingLeft (getRHS sndRule)
    
    lb = getLHS ruleK
    lc = getLHS ruleR
    
    pairL = [(apply fl x, apply fl y) |
                     x <- nodes $ domain $ codomain lb
                   , y <- nodes $ domain $ codomain lb
                   , x /= y
                   , isOrphanNode lb x
                   , not (isOrphanNode lc (apply gl x))
                   , not (isOrphanNode lc (apply gl y))]
    
    epis = calculateAllPartitions (codomain (getLHS ruleL))
    
    ret = [e | e <- epis, any (\(a,b) -> (apply e) a == (apply e) b) pairL]
    
    createNac e = if isValid ruleNac && isValid n then Just n else Nothing
      where
        n = SO.ruleMorphism ruleL ruleNac e mapK mapR
        ruleNac = buildProduction (compose (getLHS ruleL) e) (getRHS ruleL) []
        mapK = idMap (domain (getLHS ruleL)) (domain (getLHS ruleL))
        mapR = idMap (codomain (getRHS ruleL)) (codomain (getRHS ruleL))

calculateAllPartitions :: EpiPairs m => Obj m -> [m]
calculateAllPartitions graph = createAllSubobjects False graph

isOrphanNode :: TypedGraphMorphism a b -> NodeId -> Bool
isOrphanNode m n = n `elem` orphanTypedNodes m

isOrphanEdge :: TypedGraphMorphism a b -> EdgeId -> Bool
isOrphanEdge m n = n `elem` orphanTypedEdges m
