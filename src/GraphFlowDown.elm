module GraphFlowDown exposing (..)


type alias NodeKeyRep =
    { prefix : String
    , source : Source
    , id : Int
    }


nodeKeyRepToString key =
    key.prefix ++ ":" ++ sourceToString key.source ++ ":" ++ String.fromInt key.id


type alias TextKey =
    { parent : NodeKey
    , index : Int
    }


type Key
    = NodeKey NodeKeyRep
    | TextKey NodeKeyRep Int


keyToString key =
    case key of
        NodeKey rep ->
            nodeKeyRepToString rep

        TextKey rep int ->
            nodeKeyRepToString rep ++ "." ++ String.fromInt key.id


type Source
    = Elm
    | JavaScript


type Node
    = Html NodeRep
    | Text String


type alias NodeRep =
    { kind : String
    , attributes : Attributes
    , children : List NodeKey
    }


type alias Attributes =
    Dict String String


type alias CEDom =
    { root : NodeKey
    , nodes : Dict String Node
    }


domGet key dom =
    case Dict.get (keyToString key) dom.nodes  of
        Just node -> node
        Nothing -> 


domSet key value dom =
    { dom | nodes = Dict.insert (keyToString key) dom.nodes }


domRemove key dom =
    { dom | nodes = Dict.remove (keyToString key) }



diffDom old new =
    old = 
    diff (old.root, old) (new.root, new)


diff (oldKey, oldDom) (newKey, newDom) =
    if


