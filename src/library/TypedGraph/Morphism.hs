{-# OPTIONS_GHC -fno-warn-orphans #-}
module TypedGraph.Morphism (
      TypedGraphMorphism
    , idMap
    , isPartialInjective
    , invert
    , nodesFromDomain
    , edgesFromDomain
    , nodesFromCodomain
    , edgesFromCodomain
    , graphDomain
    , graphCodomain
    , mapping
    , applyNode
    , applyEdge
    , buildTypedGraphMorphism
    , checkDeletion
    , removeNodeFromDomain
    , removeEdgeFromDomain
    , removeNodeFromCodomain
    , removeEdgeFromCodomain
    , applyNodeUnsafe
    , applyEdgeUnsafe
    , createEdgeOnDomain
    , createEdgeOnCodomain
    , createNodeOnDomain
    , createNodeOnCodomain
    , updateEdgeRelation
    , updateNodeRelation
    , orphanTypedNodes
    , orphanTypedEdges
) where

import           TypedGraph.Morphism.Core
import           TypedGraph.Morphism.AdhesiveHLR                 (checkDeletion)
import           TypedGraph.Morphism.EpiPairs                    ()
import           TypedGraph.Morphism.FindMorphism                ()