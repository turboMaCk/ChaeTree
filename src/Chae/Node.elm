module Chae.Node
    exposing
        ( Node
        , singleton
        , node
        , id
        , root
        , addChild
        , children
        , hasChildren
        , toTuple
        , map
        , map2
        , flatten
        , flatMap
        , reduce
        , pushDeep
        )

{-| Node is [Rose Tree](https://en.wikipedia.org/wiki/Rose_tree) like data structure beside it also have its id.
This Id is essential to some manipulations Chae-Tree provides.
If you're looking for `Rose Tree` you'll better pick some regular implementation.
Chae Tree is domain specific with focus on building multi level navigation or similar UI elements.
It's not necessary the best pick if you want to process structural data beside you want to use functions
like `pushDeep`.

# Definition
@docs Node

# Constructors
@docs singleton, node

# Query a Node
@docs id, root, children, hasChildren, toTuple

# Common operations
@docs addChild, pushDeep

# Map - Reduce
@docs map, map2, flatten, flatMap, reduce

-}

import List
import Chae.Id exposing (..)


-- Types


{-| Node
-}
type Node a
    = Node Id a (List (Node a))



-- Common Helpers


{-| Create empty `Node` for given values.
First paramter is function which takes given value and return it's id.

    singleton "1" 1 == Node "1" 1 []
    singleton "1" { a = "b" } == Node "1" { a = "b" } []
-}
singleton : Id -> a -> Node a
singleton id item =
    Node id item []


{-| Create node. Alias for Node constructor

    node "1" 1 [] == Node "1" 1 []
    node "1" 1 [ node "2" 2 [] ] == Node "1" 1 ([Node "2" 2 []])
-}
node : Id -> b -> List (Node b) -> Node b
node id a c =
    Node id a c


{-| Get id of given `Node`.

    id (singleton "1" 1) == "1"
    id (singleton "uid" { a = "a"} ) == "uid"
-}
id : Node a -> Id
id (Node id _ _) =
    id


{-| Turns `Node` back to value it was created from.

This function provide recommended way to access user space data while working with tree.

    root (singleton "1" "Elm") == "Elm"
    root (singleton "1" { id = "1", name = "Elm" }) == { id = "1", name = "Elm" }
-}
root : Node a -> a
root (Node _ a _) =
    a


{-| Return `Node` with item add as sub `Node`.
First argument is function from item to `Id/String`.

    addChild "2" 2 (singleton "1" 1) == Node "1" 1 ([Node "2" 2 []])
    addChild "3" 3 (addChild "2" 2 (singleton "1" 1)) == Node "1" 1 ([Node "3" 3 [],Node "2" 2 []])
-}
addChild : Id -> a -> Node a -> Node a
addChild id item (Node ida a children) =
    Node ida a ((singleton id item) :: children)


{-| Get child tree of `Node`.
This is common way to access sub tree of given node.

    children (singleton "1" 1) == []
    children (addChild "2" 2 (singleton "1" 1)) == [Node "2" 2 []]
-}
children : Node a -> List (Node a)
children (Node _ _ children) =
    children


{-| Check if tree has children

    hasChildren (singleton "1" 1) == False
    hasChildren (addChild "2" 2 (singleton "1" 1)) == True
-}
hasChildren : Node a -> Bool
hasChildren tree =
    children tree |> List.isEmpty |> not


{-| Transform node to tuple of `( id, item, children )`

    toTuple (singleton "1" 1) == ("1",1,[])
    toTuple (node "1" 1 [(singleton "2" 2)]) == ("1",1,[Node "2" 2 []])
-}
toTuple : Node a -> ( Id, a, List (Node a) )
toTuple (Node id a c) =
    ( id, a, c )



-- Common operations


{-| Map function on tree
produces new modified tree

   map toId ((+) 1) (addChild "2" 2 (singleton "1" 1)) == Node "1" 2 ([Node "2" 3 []])
   map (\n -> n + 1 |> toId) ((+) 1) (addChild "2" 2 (singleton "1" 1)) == Node "2" 2 ([Node "3" 3 []])
-}
map : (a -> Id) -> (a -> b) -> Node a -> Node b
map getId fc (Node _ a c) =
    Node (getId a) (fc a) (List.map (map getId fc) c)


{-| Similar to map, but takes two Nodes and produce new one by combining items of both
-}
map2 : (a -> b -> Id) -> (a -> b -> c) -> Node a -> Node b -> Node c
map2 getId fc (Node _ a ca) (Node _ b cb) =
    Node (getId a b) (fc a b) (List.map2 (map2 getId fc) ca cb)


{-| Similar to `List.zip` but working with Node
-}
zip : (a -> b -> Id) -> Node a -> Node b -> Node ( a, b )
zip getId =
    map2 getId (,)


{-| Flatten Node of Nodes to Node.
-}
flatten : (Id -> Id -> Id) -> Node (Node a) -> Node a
flatten getId (Node id1 (Node id2 a c) cs) =
    Node (getId id1 id2) a (c ++ List.map (flatten getId) cs)


{-| Map and flatten

    n = node "1" 1 [ node "2" 2 [], node "3" 3 [ node "4" 4 []]]

    flatMap toId (\a -> node "2" (a * 2) []) n == Node "1" 2 ([Node "2" 4 [],Node "3" 6 ([Node "4" 8 []])])
    flatMap toId (\a -> node "2" (a *2) [node  "1" (a * 3) []]) m == Node "1" 2 ([Node "1" 3 [],Node "2" 4 ([Node "1" 6 []]),Node "3" 6 ([Node "1" 9 [],Node "4" 8 ([Node "1" 12 []])])])
-}
flatMap : (a -> Id) -> (a -> Node b) -> Node a -> Node b
flatMap getId fc =
    map getId fc >> (flatten (\aid _ -> aid))


{-| Reduce Node by given function. Similar to `List.foldr`

    reduce (+) 0 (addChild "20" 20 (singleton "1" 1)) == 21
    reduce (*) 1 (addChild "3" 3 (singleton "4" 4)) == 12
-}
reduce : (a -> b -> b) -> b -> Node a -> b
reduce reducer b (Node _ a c) =
    List.foldl (flip (reduce reducer)) (reducer a b) c


{-| Find parent node in children by id and push new item to it

    n = node "1" 1 [ node "2" 2 [], node "3" 3 [ node "4" 4 []]]

    pushDeep "4" "10" 10 n == Node "1" 1 ([Node "2" 2 [],Node "3" 3 ([Node "4" 4 ([Node "10" 10 []])])])
-}
pushDeep : Id -> Id -> a -> Node a -> Node a
pushDeep id aid item ((Node nodeId a children) as node) =
    if nodeId == id then
        addChild aid item node
    else
        Node nodeId a (List.map (pushDeep id aid item) children)
