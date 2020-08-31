module FlowDown exposing (..)

import CEDom exposing (..)


type CEDom
    = Node NodeRep
    | Text String

type alias NodeRep =         { kind : String
        , attributes : Attributes
        , children : List (String, CEDom)
        }

type alias Attributes = Dict String String

node kind attrs children = 
    Node <| {kind = kind, attributes = Dict.fromList attributes, children = children}

div = node kind

text value = Text value


type Diff
    = ReplaceText String
    | Replace CEDom
    | RemoveAttribute String
    | SetAttribute String String
    | Batch (List Diff)
    | Descend Int Diff


diff: CEDom -> CEDom -> Maybe Diff
diff old new =
    if old == new then
        Nothing

    else
        case ( old, new ) of
            ( Text oldValue, Text newValue ) ->
                if oldValue /= newValue then
                    Just <| ReplaceText newValue

                else
                    Nothing

            ( Node oldNode, Node newNode ) ->
                if oldNode.kind /= newNode.kind then
                    Just <| Replace new

                else
                    let
                        attributeDiffs =
                            diffAttributes oldNode.attributes newNode.attributes

                        childDiffs =
                            diffChildren oldNode.children newNode.children
                    in
                    mergeDiffs attributeDiffs childDiffs

            _ ->
                Just <| Replace new

diffChildren: CEDom -> CEDom -> Maybe Diff
diffChildren old new =
    if old == new then Same
    else 
        let 
            removed_nodes = old |> List.filter (\(oldKey, oldValue) -> List.any (\(newKey, newValue) -> newKey == oldKey) new)
            
            
    case (old, new) of
        (o, n::ew) -> a 
        (


diffAttributes: Attributes -> Attributes -> Maybe Diff
diffAttributes old new =
    if old == new then
        Same

    else
        Batch <| Dict.merge (\key value accum -> RemoveAttribute key :: accum)
            (\key value accum -> SetAttribute key value :: accum)
            (\key value accum -> SetAttribute key value :: accum)
            old
            new
            []


mergeDiffs: Maybe Diff -> Maybe Diff -> Maybe Diff
mergeDiffs left right =
    case ( left, right ) of
        (Nothing, _) -> right
        (_, Nothing) -> left
        (Just (Batch l), Just (Batch r)) -> Just (Batch (List.append l r))
        (Just (Batch l), Just r) -> Just (Batch (List.append l [r]))
        (Just l, Just (Batch r)) -> Just (Batch l::r)
        (Just l, Just r) -> Batch [l, r]





--Flow-down/around
--1. CE starts empty
--2. Elm generates view HTML
--3. Elm serializes & pushes a big insertion diff to JS
--4. JS deserializes, builds elmDOM, and shoves into CE
--5. Mutation observer fires, sends batch of mutations
--6. JS serializes mutations and ships them back to Elm
--7. Elm desereilizes and mutates empty initial dom to create ceDOM (separate from elmDOM)
--8. At this point, ceDOM and elmDOM should be comparably equal!
--9. Add some Elm buttons that mutate the elmDOM, and confirm flow-through to CEDOM


type alias Model =
    { elmDom : CEDom
    , jsDom : CEDom
    }


contentEditableId =
    "editor"


type ElmToJsMsg
    = Patch Diff


init flags =
    let
        model =
            { elmDom = div [ ( "contentEditable", "true" ) ] [ text "Hello world" ], jsDom = div [ ( "contentEditable", "true" ) ] [] }
    in
    ( model, diffChildren model.elmDom model.jsDom |> patch )


type alias Msg =
    NoOp


update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


init flags =
    ()
