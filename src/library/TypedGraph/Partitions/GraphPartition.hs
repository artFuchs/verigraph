module TypedGraph.Partitions.GraphPartition (
   Node (..),
   Edge (..),
   Graph,
   GraphPartition,
   getNode,
   genGraphEqClass
   ) where

import           Data.Maybe (mapMaybe)

-- | A Node with the needed information for generating equivalence classes
data Node = Node {
    nodeType   :: Int,
    nodeName   :: Int,
    nodeId     :: Int,
    injectiveNode    :: Bool, --injective flag
    nodeFromLeft :: Bool
    }

instance Show Node where
  show (Node nodeType nodeName nodeId injectiveNode nodeFromLeft) =
    show nodeName ++ ":" ++ show nodeType ++ ":" ++
    (if nodeFromLeft then "Left" else "Right") ++ " (id:" ++ show nodeId ++") {"++ show injectiveNode ++"}"

instance Eq Node where
  (Node nodeType1 nodeName1 _ _ fromLeft1) == (Node nodeType2 nodeName2 _ _ fromLeft2) =
    nodeType1 == nodeType2 && nodeName1 == nodeName2 && fromLeft1 == fromLeft2

-- | An Edge with the needed informations for the generating equivalence classes algorithm
data Edge = Edge {
    edgeType   :: Int,
    label   :: Int,
    edgeId     :: Int,
    source  :: Node,
    target  :: Node,
    injectiveEdge    :: Bool, --injective flag
    edgeFromLeft :: Bool
    } deriving (Eq)

instance Show Edge where
  show (Edge edgeType label edgeId (Node _ sourceName _ _ _) (Node _ targetName _ _ _) injectiveEdge edgeFromLeft) =
    show label ++ ":" ++
    show edgeType ++ "(" ++
    show sourceName ++ "->" ++
    show targetName ++ ")" ++
    (if edgeFromLeft then "Left" else "Right") ++
    " (id:" ++ show edgeId ++") {"++ show injectiveEdge ++"}"

-- | Graph data for generating equivalence classes
type Graph = ([Node],[Edge])

-- | An equivalence class of a 'Graph'

-- | TODO: use Data.Set?
type GraphPartition = ([[Node]],[[Edge]])

{-partitions-}

-- | Checks if two nodes are in the same equivalence class
checkNode :: Node -> [Node] -> Bool
checkNode _ [] = error "error checkNode in GraphPartition"
checkNode (Node type1 _ _ inj side) l@(Node type2 _ _ _ _ : _) =
  type1 == type2 && (not inj || not checkInj)
  where --checks if another inj node is in this list
    checkInj = any (\(Node _ _ _ inj side2) -> inj && side == side2) l

-- | Checks if two edges are in the same equivalence class
-- Needs @nodes@ to know if a source or target was collapsed
checkEdge :: [[Node]] -> Edge -> [Edge] -> Bool
checkEdge _ _ [] = error "error checkEdge in GraphPartition"
checkEdge nodes (Edge type1 _ _ s1 t1 inj side) l@(Edge type2 _ _ s2 t2 _ _ : _) = exp1 && exp2 && exp3
  where
    exp1 = type1 == type2 && (not inj || not checkInj)
    --checks if another inj edge is in this list
    checkInj = any (\(Edge _ _ _ _ _ inj side2) -> inj && side == side2) l
    nameAndSrc node = (nodeName node, nodeFromLeft node)
    l1   = getNode (nameAndSrc s1) nodes
    l2   = getNode (nameAndSrc s2) nodes
    exp2 = l1 == l2
    l3   = getNode (nameAndSrc t1) nodes
    l4   = getNode (nameAndSrc t2) nodes
    exp3 = l3 == l4

-- | Runs generator of partitions for nodes, and after for edges according to the nodes generated
genGraphEqClass :: Graph -> [GraphPartition]
genGraphEqClass gra = concatMap f a
  where
    nodes = fst
    edges = snd
    a = part checkNode (nodes gra)
    b x = part (checkEdge x) (edges gra)
    f :: [[Node]] -> [([[Node]],[[Edge]])]
    f a = zip (replicate (length (b a)) a) (b a)

-- | Interface function to run the algorithm that generates the partitions
part :: (a -> [a] -> Bool) -> [a] -> [[[a]]]
part f l = if null l then [[]] else bt f l []

-- | Runs a backtracking algorithm to create all partitions
-- receives a function of restriction, to know when a element can be combined with other
bt :: (a -> [a] -> Bool) -> [a] -> [[a]] -> [[[a]]]
bt f toAdd [] = bt f (init toAdd) [[last toAdd]]
bt _ [] actual = [actual]
bt f toAdd actual =
  bt f initAdd ([ad]:actual) ++
    concat
      (mapMaybe
        (\(n,id) -> if f ad n
                      then
                        Just (bt f initAdd (replace id (ad:n) actual))
                      else
                        Nothing)
      (zip actual [0..]))
  where
    initAdd = init toAdd
    ad = last toAdd

-- | Replaces the @idx@-th element by @new@ in the list @l@
replace :: Int -> a -> [a] -> [a]
replace idx new l = take idx l ++ [new] ++ drop (idx+1) l

-- | Returns the node that this @p@ was collapsed in partitions
-- Used to compare if an edge can be mixed with another
-- GraphPartitionToVerigraph use to discover source and target of edges
getNode :: (Int,Bool) -> [[Node]] -> Node
getNode p@(name,source) (x:xs) =
  if any (\n -> nodeName n == name && nodeFromLeft n == source) x
    then
      head x
    else
      getNode p xs
getNode _ [] = error "error when generating overlapping pairs (getListNode)"
