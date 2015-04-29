{-# LANGUAGE TemplateHaskell #-} -- fclabels

{-
module GUI.Editing (
      GramState (..)
    , GraphEditState (..)
    , CanvasMode (..)
    , SelMode (..)
    , RowStatus (..)
    , Graph
    , Obj (..)
    , Key
    , currentGraphState
    , grammarToState
    , grammarToModel
    , setCurGraphState
    , stateToModel
    , modCurGraphState
    , getGraph
    , getTypeGraph 
    , TreeNode (..)
    ) where
-}

module GUI.Editing where

    
import qualified Graph.Graph as G
import qualified Graph.GraphMorphism as GM
import qualified Graph.GraphGrammar as GG
import qualified Graph.GraphRule as GR
import qualified Abstract.Morphism as M
import qualified Abstract.Relation as R
import Graphics.Rendering.Cairo (Render)
import Graphics.UI.Gtk (Color, TreeStore, treeStoreNew, treeStoreInsert)
import Data.Label -- fclabels
import Data.List.Utils

defGraphName = "g0"
type Grammar = GG.GraphGrammar NodePayload EdgePayload
type Graph = G.Graph NodePayload EdgePayload
type GraphMorphism = GM.GraphMorphism NodePayload EdgePayload
type Rule = GR.GraphRule NodePayload EdgePayload
type Coords = (Double, Double)
type NodePayload =
    ( Coords
    , GramState -> GraphEditState -> G.NodeId -> Render ()
    , Coords -> Coords -> Bool)
type EdgePayload = Color
data Obj = Node Int | Edge Int
    deriving (Show, Eq)

data TreeNode
    = TNInitialGraph RowStatus Key
    | TNTypeGraph
    | TNRule RowStatus Key
    | TNRoot Key

instance Show TreeNode where
    show (TNInitialGraph _ s ) = s
    show TNTypeGraph = "Type Graph"
    show (TNRule _ s) = s
    show (TNRoot s) = s


-- To keep it uniform, typegraphs are also described as GraphEditState
data GramState = GramState
    { _canvasMode       :: CanvasMode
    , _getInitialGraphs :: [(Key, GraphEditState)]
    , _getTypeGraph    :: GraphEditState
    , _getRules         :: [(Key, GraphEditState)]
    }

data GraphEditState = GraphEditState
    { _getStatus :: RowStatus
    , _selObjects :: [Obj]
    , _mouseMode :: MouseMode
    , _refCoords :: Coords
    , _getGraph :: Graph
    , _getNodeRelation :: R.Relation G.NodeId
    , _getEdgeRelation :: R.Relation G.EdgeId
    } deriving Show

data CanvasMode =
      IGraphMode Key
    | TGraphMode
    | RuleMode Key
    deriving Show


{-
data SelMode =
      SelObjects [Obj]
--  | DragNodes [G.NodeId]
    | DrawEdge G.NodeId
    | []
    deriving Show
-}

data MouseMode = SelMode | EdgeCreation Int
    deriving Show

data RowStatus = Active | Inactive
    deriving (Eq, Show)

type Key = String

$(mkLabels [''GramState, ''GraphEditState])

currentGraphState :: GramState -> Maybe GraphEditState
currentGraphState state =
    case _canvasMode state of
        IGraphMode k -> lookup k iGraphs
        TGraphMode -> Just tGraph
        RuleMode k -> lookup k rules
  where
    iGraphs = _getInitialGraphs state
    tGraph = _getTypeGraph state
    rules = _getRules state

setCurGraphState :: GraphEditState -> GramState -> GramState
setCurGraphState gstate' state =
    case _canvasMode state of
        IGraphMode k ->
            modify getInitialGraphs
                   (\s -> addToAL s k gstate')
                   state
        TGraphMode ->
            set getTypeGraph gstate' state
        otherwise -> state

modCurGraphState :: (GraphEditState -> GraphEditState) -> GramState -> GramState
modCurGraphState f state =
    case gstate' of
        Just gstate' -> setCurGraphState gstate' state
        Nothing -> state
  where
    gstate' = fmap f $ currentGraphState state

grammarToState :: Grammar -> GramState
grammarToState gg =
    GramState (IGraphMode defGraphName) iGraphList tGraph rulesList
  where
    iGraph = GG.initialGraph gg
    iNodeRel = GM.nodeRelation iGraph
    iEdgeRel = GM.edgeRelation iGraph
    iGraphEditState =
        GraphEditState Active [] SelMode (0, 0) (M.domain iGraph) iNodeRel iEdgeRel
    emptyRel = R.empty [] []
    tGraph =
        GraphEditState Active [] SelMode (0, 0) (GG.typeGraph gg) emptyRel emptyRel
    iGraphList = [(defGraphName, iGraphEditState)]
    rulesList = []
--    rules  = GG.rules gg
--    ruleToGraphEditState 
--    rulesMap = foldr (\(s, r) acc -> M.insert s r acc) M.empty rules

stateToModel :: GramState -> IO (TreeStore TreeNode)
stateToModel state = do
    tree <- treeStoreNew [] :: IO (TreeStore TreeNode)
    treeStoreInsert tree [] 0 $ TNInitialGraph Active defGraphName
    treeStoreInsert tree [] 2 $ TNTypeGraph
--    treeStoreInsertTree tree [] 2 ruleTree
    return tree
  where
    rules = _getRules state
    tGraph = _getTypeGraph state
    

grammarToModel :: Grammar -> IO (TreeStore TreeNode)
grammarToModel = stateToModel . grammarToState

testGrammar :: Grammar
testGrammar =
    GG.graphGrammar iGraph []
  where
    iGraph = GM.graphMorphism g t nR eR
    g = G.empty :: Graph
    t = G.empty :: Graph
    nR = R.empty [] []
    eR = R.empty [] []
