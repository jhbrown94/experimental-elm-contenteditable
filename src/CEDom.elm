module CEDom exposing (..)


type Dom
    = Dom DomRep


type alias DomRep =
    { root : List Node
    , nodes : Dict String Node
    }


type Node
    = Text String
    | Element String (List Attribute) (List Node)


type alias NodeRep =
    { kind : String
    , attributes : List ( String, String )
    , children : List Node
    }


node kind attrs children =
    Element { kind = kind, attributes = attrs, children = children }
