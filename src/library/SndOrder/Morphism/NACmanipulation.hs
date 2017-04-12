module SndOrder.Morphism.NACmanipulation where

import           Abstract.AdhesiveHLR
import           Abstract.DPO
import           Abstract.Morphism
import           TypedGraph.Morphism
import           SndOrder.Morphism.Cocomplete       ()

-- | Auxiliar structure and function to delete first-order NACs
data DeleteScheme = DisableDelete | Monomorphisms | InitialPushouts

deleteStep :: DeleteScheme -> TypedGraphMorphism a b -> [TypedGraphMorphism a b] -> [TypedGraphMorphism a b] -> [TypedGraphMorphism a b]

deleteStep DisableDelete _ _ concreteNACs = concreteNACs

deleteStep Monomorphisms _ modeledNACs concreteNACs =
  [nn' | nn' <- concreteNACs, all (`maintainTest` nn') modeledNACs]
    where
      findMorph :: TypedGraphMorphism a b -> TypedGraphMorphism a b -> [TypedGraphMorphism a b]
      findMorph a b = findMorphisms Monomorphism (codomain a) (codomain b)
      
      --it forces commuting 
      --maintainTest a b = Prelude.null $ filter (\morp -> compose a morp == compose match b) (findMorph a b)
      maintainTest a b = Prelude.null $ findMorph a b

deleteStep InitialPushouts _ modeledNACs concreteNACs =
  [fst nn' | nn' <- ipoConcrete, all (\nn -> not (verifyIsoBetweenMorphisms nn (snd nn'))) ipoModeled]
  where
    ipoModeled = map ((\ (_, x, _) -> x) . calculateInitialPushout) modeledNACs
    ipoConcrete = map (\(n,(_,x,_)) -> (n,x)) (zip concreteNACs (map calculateInitialPushout concreteNACs))

verifyIsoBetweenMorphisms :: TypedGraphMorphism a b -> TypedGraphMorphism a b -> Bool
verifyIsoBetweenMorphisms n n' = not $ Prelude.null comb
  where
    findIsoDom = findIso domain n n'
    findIsoCod = findIso codomain n n'
    comb = [(d,c) | d <- findIsoDom, c <- findIsoCod, compose d n' == compose n c]

findIso :: FindMorphism m => (t -> Obj m) -> t -> t -> [m]
findIso f x y = findMorphisms Isomorphism (f x) (f y)

-- | Auxiliar structure and function to create first-order NACs
data CreateScheme = DisableCreate | Pushout | ShiftNACs

createStep :: CreateScheme -> TypedGraphMorphism a b -> [TypedGraphMorphism a b] -> [TypedGraphMorphism a b]

createStep DisableCreate _ _ = []

createStep Pushout match modeledNACs =
  map (snd . calculatePushout match) modeledNACs

createStep ShiftNACs match modeledNACs =
  concatMap (nacDownwardShift conf match) modeledNACs
    where
      -- conf is used only to indicate AnyMatches, that is the most generic case for nacDownwardShift
      conf = MorphismsConfig AnyMatches MonomorphicNAC