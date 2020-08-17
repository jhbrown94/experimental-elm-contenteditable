module CEDom exposing (Attribute, Change(..), diff, element, text)

import Dict exposing (Dict)


type Dom
    = Dom DomRep


type alias DomRep =
    { root : List Node
    , nodes : Dict String Node
    }


type Node
    = Text String
    | Element ElementRep


type alias ElementRep =
    { kind : String
    , attributes : List Attribute
    , children : List Node
    }


element kind attributes children =
    Element <| ElementRep kind attributes children


text string =
    Text string


type alias Attribute =
    { name : String, value : String }


type Change
    = ReplaceText String
    | ReplaceAttributes (List Attribute)
    | ReplaceNode Node
    | Batch (List Change)
    | Nested Int Change


node kind attrs children =
    Element { kind = kind, attributes = attrs, children = children }



-- TODO this is so not finished


diff old new =
    case ( old, new ) of
        ( Text l, Text r ) ->
            if l == r then
                []

            else
                [ ReplaceText r ]

        ( Element l, Element r ) ->
            if l == r then
                []

            else
                let
                    attributeChanges =
                        if l.attributes == r.attributes then
                            []

                        else
                            [ ReplaceAttributes r.attributes ]

                    childrenChanges =
                        diffChildren l.children r.children
                in
                [ Batch (attributeChanges ++ childrenChanges) ]

        ( l, r ) ->
            [ ReplaceNode new ]


diffChildren old new =
    []
