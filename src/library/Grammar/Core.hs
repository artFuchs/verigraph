{-|
Description : Grammar structure.

Maintainer  : Andrei Costa <acosta@inf.ufrgs.br>
Stability   : experimental

A grammar is defined as a start object, a set of transformation rules,
and a set of constraints for the potencial generated objects.
The morphism type is kept generic.
-}

module Grammar.Core (
      grammar
    , Grammar
    , ObjectFlow (..)
    , NamedProduction
    , getProductionName
    , getProduction
    , start
    , constraints
    , rules
) where

import           Abstract.AdhesiveHLR
import           Abstract.DPO.Core
import           Abstract.Morphism

type NamedProduction m = (String, Production m)

data Grammar m =
  Grammar {
      start       :: Obj m
    , constraints :: [Constraint m]
    , rules       :: [NamedProduction m]
    }

grammar :: Obj m -> [Constraint m] -> [NamedProduction m] -> Grammar m
grammar = Grammar

getProductionName :: NamedProduction m -> String
getProductionName = fst

getProduction :: NamedProduction m -> Production m
getProduction = snd

-- | Object that uses a Span of Morphisms to connect the right-hand-side of a Production with the left-hand-side of another one
data ObjectFlow m =
  ObjectFlow {
  index :: String -- ^ A identifier for the Object Flow
, producer :: String -- ^ The name of the production that will produce the input for the next
, consumer :: String -- ^ The name of the production that uses the result of the other
, spanMapping :: Span m -- ^ A span of Morphisms @Ri <- IO -> Lo@ where @Ri@ is the right-hand-side of the @producer production@ and @Lo@ is the left-hand-side of the @consumer production@
}
