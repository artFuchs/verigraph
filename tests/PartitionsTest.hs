{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}

import           Math.Combinat.Numbers (bellNumber)
import           Test.HUnit

import           Category.AdhesiveHLR
import           Category.DPO
import           Analysis.CriticalPairs
import           Object.Graph
import           Graph.GraphMorphism
import           SndOrder.Morphism
import           TypedGraph.Morphism   hiding (createEdgeOnDomain, createNodeOnDomain)
import           Utils
import qualified XML.GGXReader as XML

main :: IO ()
main = do
  let fileName1 = "tests/grammars/sndOrderEpi.ggx"
      fileName2 = "tests/grammars/partialInjectivity.ggx"
      dpoConf1 = MorphismsConfig MonoMatches MonomorphicNAC
      dpoConf2 = MorphismsConfig AnyMatches MonomorphicNAC
      dpoConf3 = MorphismsConfig MonoMatches PartiallyMonomorphicNAC
      dpoConf4 = MorphismsConfig AnyMatches PartiallyMonomorphicNAC
  
  (gg1a1,gg2a1,_) <- XML.readGrammar fileName1 False dpoConf1
  (gg1b1,gg2b1,_) <- XML.readGrammar fileName1 False dpoConf2
  (gg1c1,gg2c1,_) <- XML.readGrammar fileName1 False dpoConf3
  (gg1d1,gg2d1,_) <- XML.readGrammar fileName1 False dpoConf4
  (gg1a2,_,_) <- XML.readGrammar fileName2 False dpoConf1
  (gg1b2,_,_) <- XML.readGrammar fileName2 False dpoConf2
  (gg1c2,_,_) <- XML.readGrammar fileName2 False dpoConf3
  (gg1d2,_,_) <- XML.readGrammar fileName2 False dpoConf4
  
  runTests
    [ testPartition
    , testProduceForbid dpoConf1 gg1a2 18
    , testProduceForbid dpoConf2 gg1b2 18
    , testProduceForbid dpoConf3 gg1c2 18
    , testProduceForbid dpoConf4 gg1d2 30
    , testCreateJointlyEpimorphicPairsFromNAC dpoConf1 gg1a1 gg2a1 21
    , testCreateJointlyEpimorphicPairsFromNAC dpoConf2 gg1b1 gg2b1 26
    , testCreateJointlyEpimorphicPairsFromNAC dpoConf3 gg1c1 gg2c1 34
    , testCreateJointlyEpimorphicPairsFromNAC dpoConf4 gg1d1 gg2d1 43]

-- Tests the number of produce-forbid conflicts, it is linked to the
-- overlappings generated by CreateJointlyEpimorphicPairsFromNAC.
testProduceForbid conf gg n = length proFor ~?= n
  where
    rL = snd (head (productions gg))
    rR = snd (head (tail (productions gg)))
    
    proFor = findAllProduceForbid conf rL rR

-- Tests the number of overlapping pairs generated by createJointlyEpimorphicPairsFromNAC
testCreateJointlyEpimorphicPairsFromNAC conf gg1 gg2 n = length epi ~?= n
  where
    r1 = snd (head (productions gg1))
    r2 = snd (head (productions gg2))
    
    rr1 = buildProduction (getLHS r1) (getRHS r1) []
    rr2 = head (getNACs r2)
    
    epi = createJointlyEpimorphicPairsFromNAC conf (codomain (getLHS rr1)) (mappingLeft rr2)

-- Tests if the partition generation algorithm generates all expected number of combinations
testPartition =
  test (
  -- Tests if a graph with the same repeated node n times has partitions length equals to the n-th bell number
  map
    (\n ->
       ("BellNumber " ++ show n ++ " nodes") ~:
       fromInteger (bellNumber n) ~=?
       length (getPart (graph1 [1..n])))
    ids
    :
    -- Tests if a graph with the same repeated edge n times has partitions length equals to the n-th bell number
    [map
      (\e ->
         ("BellNumber " ++ show e ++ " edges") ~:
         fromInteger (bellNumber e) ~=?
         length (getPart (graph2 [1..e])))
      ids])

getPart :: GraphMorphism (Maybe a) (Maybe b) -> [TypedGraphMorphism a b]
getPart = createAllSubobjects False

limitBellNumber = 8
ids = [1..limitBellNumber]

--typegraph: graph with one node and one edge on itself
typegraph = insertEdge (EdgeId 0) (NodeId 0) (NodeId 0) (insertNode (NodeId 0) Object.Graph.empty)

--graph1: typed graph with 'limitBellNumber' nodes of same type
initGraph1 = Graph.GraphMorphism.empty Object.Graph.empty typegraph
graph1 = foldr (\n -> createNodeOnDomain (NodeId n) (NodeId 0)) initGraph1

--graph2: typed graph with 'limitBellNumber' edges of same type with the same source and target
initGraph2 = Graph.GraphMorphism.empty (insertNode (NodeId 0) Object.Graph.empty) typegraph
graph2 = foldr
           (\e -> createEdgeOnDomain (EdgeId e) (NodeId 0) (NodeId 0) (EdgeId 0))
           (updateNodes (NodeId 0) (NodeId 0) initGraph2)
