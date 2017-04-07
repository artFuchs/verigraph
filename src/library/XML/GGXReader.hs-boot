module XML.GGXReader where

import qualified Graph.Graph             as G
import           TypedGraph.DPO.GraphRule
import           TypedGraph.Morphism
import           TypedGraph.Graph
import           XML.ParsedTypes

instantiateRule :: G.Graph (Maybe a) (Maybe b) -> RuleWithNacs -> GraphRule a b

instantiateSpan :: TypedGraph a b -> TypedGraph a b -> [Mapping] -> (TypedGraphMorphism a b, TypedGraphMorphism a b)
