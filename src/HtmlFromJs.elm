port module HtmlFromJs exposing (..)

import Browser
import Dict
import Html as H
import Html.Attributes as HA
import Json.Decode as Decode
import Maybe.Extra as MaybeX



-- Node
--
-- Reference:
-- https://developer.mozilla.org/en-US/docs/Web/API/Node


type alias Node =
    { ref : NodeRef
    , previousSibling : Maybe NodeRef
    , nextSibling : Maybe NodeRef
    , parentNode : Maybe NodeRef
    , content : Content
    }


decodeNode =
    Decode.map5 Node
        (Decode.field "ref" decodeNodeRef)
        (Decode.field "previousSibling" decodeMaybeNodeRef)
        (Decode.field "nextSibling" decodeMaybeNodeRef)
        (Decode.field "parentNode" decodeMaybeNodeRef)
        (Decode.field "content" decodeContent)


type alias NodeRef =
    Int


type alias DomFragment =
    Dict.Dict NodeRef Node


rootNodeRef =
    0


type Content
    = Text String
    | HtmlNode HtmlRep


type alias HtmlRep =
    { kind : String
    , attributes : Attributes
    , firstChild : Maybe NodeRef
    }


decodeContent =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\type_ ->
                case type_ of
                    "text" ->
                        decodeTextContent

                    "html" ->
                        decodeHtmlContent

                    _ ->
                        logError "Unknown node type" type_ (Decode.fail ("Unknown node type " ++ type_))
            )


decodeTextContent =
    Decode.map Text (Decode.field "value" Decode.string)


decodeHtmlContent =
    Decode.map HtmlNode <|
        Decode.map3 HtmlRep
            (Decode.field "tag" Decode.string)
            (Decode.field "attributes" decodeAttributes)
            (Decode.field "firstChild" decodeMaybeNodeRef)


type alias Attributes =
    Dict.Dict String String


decodeAttributes =
    Decode.dict Decode.string


firstChild html =
    html.firstChild


lastChild : HtmlRep -> DomFragment -> Maybe Node
lastChild html domFragment =
    let
        find child =
            case child.nextSibling of
                Nothing ->
                    child

                Just r ->
                    find (getNode r domFragment)
    in
    Maybe.map (\n -> getNode n domFragment |> find) html.firstChild


children html graph =
    let
        gather ref kids =
            case ref of
                Nothing ->
                    kids

                Just r ->
                    gather (getNode r graph |> .nextSibling) (r :: kids)
    in
    List.reverse (gather html.firstChild [])


newDomFragment : Content -> ( DomFragment, NodeRef )
newDomFragment content =
    ( addNode rootNodeRef content Dict.empty
    , rootNodeRef
    )


getNode : NodeRef -> DomFragment -> Node
getNode ref domFragment =
    case Dict.get ref domFragment of
        Nothing ->
            logError "Received a reference for a node which I don't know about." ref (Node ref Nothing Nothing Nothing (Text "This node is an internal error"))

        Just n ->
            n


maybeGetNode : Maybe NodeRef -> DomFragment -> Maybe Node
maybeGetNode ref domFragment =
    Maybe.map (\r -> getNode r domFragment) ref


getNodeList refList domFragment =
    List.map (\ref -> getNode ref domFragment) refList


setNode : Node -> DomFragment -> DomFragment
setNode node domFragment =
    Dict.insert node.ref node domFragment


maybeSetNode : Maybe Node -> DomFragment -> DomFragment
maybeSetNode node domFragment =
    Maybe.map (\n -> setNode n domFragment) node |> Maybe.withDefault domFragment


addNode : NodeRef -> Content -> DomFragment -> DomFragment
addNode ref content fragment =
    Dict.insert ref (Node ref Nothing Nothing Nothing content) fragment


appendChild : NodeRef -> NodeRef -> DomFragment -> DomFragment
appendChild childRef parentRef domFragment =
    let
        parent =
            getNode parentRef domFragment

        child =
            getNode childRef domFragment
    in
    if child.parentNode /= Nothing then
        logError "Attempting to append child that already has a parent" ( childRef, parentRef ) domFragment

    else
        case parent.content of
            HtmlNode html ->
                case lastChild html domFragment of
                    Nothing ->
                        domFragment
                            |> setNode { child | parentNode = Just parentRef }
                            |> setNode { parent | content = HtmlNode { html | firstChild = Just childRef } }

                    Just priorLast ->
                        domFragment
                            |> setNode { child | parentNode = Just parentRef, previousSibling = Just priorLast.ref }
                            |> setNode { priorLast | nextSibling = Just childRef }

            _ ->
                logError "Attempting to append child to non-html node" ( childRef, parentRef ) domFragment



-- MutationRecord
-- Reference
-- https://developer.mozilla.org/en-US/docs/Web/API/MutationRecord


type MutationPayload
    = AttributeMuxation String (Maybe String)
    | CharacterData String
    | ChildListMutation ChildListRep


type alias MutationRecord =
    { target : NodeRef
    , mutation : MutationPayload
    }


type alias ChildListRep =
    { addedNodes : List NodeRef
    , removedNodes : List NodeRef
    , previousSibling : Maybe NodeRef
    , nextSibling : Maybe NodeRef
    }


decodeMutationRecord =
    Decode.map2 MutationRecord
        (Decode.field "target" decodeNodeRef)
        (Decode.field "mutation" decodeMutationContent)


decodeMutationContent : Decode.Decoder MutationPayload
decodeMutationContent =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\type_ ->
                case type_ of
                    "attributes" ->
                        decodeAttributeMuxation

                    "characterData" ->
                        decodeCharacterDataMutation

                    "childList" ->
                        decodeChildListMutation

                    _ ->
                        logError "Unknown MutationRecord type" type_ (Decode.fail ("Unknown MutationRecord type " ++ type_))
            )


decodeAttributeMuxation =
    Decode.map2 AttributeMuxation
        (Decode.field "attributeName" Decode.string)
        (Decode.field "attributeValue" (Decode.nullable Decode.string))


decodeCharacterDataMutation =
    Decode.map CharacterData (Decode.field "characterValue" Decode.string)


decodeChildListMutation =
    Decode.map ChildListMutation <|
        Decode.map4 ChildListRep
            (Decode.field "addedNodes" decodeNodeRefList)
            (Decode.field "removedNodes" decodeNodeRefList)
            (Decode.field "previousSibling" decodeMaybeNodeRef)
            (Decode.field "nextSibling" decodeMaybeNodeRef)


decodeNodeRef =
    Decode.int


decodeMaybeNodeRef =
    Decode.nullable Decode.int


decodeNodeRefList =
    Decode.list decodeNodeRef



-- Applications


applyMutationRecord { target, mutation } domFragment =
    let
        node =
            getNode target domFragment
    in
    case ( node.content, mutation ) of
        ( Text _, AttributeMuxation _ _ ) ->
            logError "Trying to change attribute on a text node" ( node, mutation ) domFragment

        ( HtmlNode html, AttributeMuxation name (Just value) ) ->
            Dict.insert target { node | content = HtmlNode { html | attributes = Dict.insert name value html.attributes } } domFragment

        ( HtmlNode html, AttributeMuxation name Nothing ) ->
            Dict.insert target { node | content = HtmlNode { html | attributes = Dict.remove name html.attributes } } domFragment

        ( Text _, CharacterData value ) ->
            Dict.insert target { node | content = Text value } domFragment

        ( HtmlNode _, CharacterData _ ) ->
            logError "Trying to change text data on an attrribute node" ( node, mutation ) domFragment

        ( Text _, ChildListMutation _ ) ->
            logError "Trying to mutate children of a text node" ( node, mutation ) domFragment

        ( HtmlNode html, ChildListMutation childMutation ) ->
            let
                previousSiblingRef =
                    childMutation.previousSibling

                newPreviousSibling =
                    maybeGetNode previousSiblingRef domFragment
                        |> Maybe.map
                            (\previousSibling ->
                                { previousSibling
                                    | nextSibling =
                                        case List.head childMutation.addedNodes of
                                            Nothing ->
                                                nextSiblingRef

                                            Just v ->
                                                Just v
                                }
                            )

                nextSiblingRef =
                    childMutation.nextSibling

                newNextSibling =
                    maybeGetNode nextSiblingRef domFragment
                        |> Maybe.map
                            (\nextSibling ->
                                { nextSibling
                                    | previousSibling =
                                        case List.head (List.reverse childMutation.addedNodes) of
                                            Nothing ->
                                                previousSiblingRef

                                            Just v ->
                                                Just v
                                }
                            )

                addedNodes =
                    List.map (\ref -> getNode ref domFragment |> (\node_ -> { node_ | parentNode = Just target })) childMutation.addedNodes

                fixedPrevious : Maybe NodeRef -> List Node -> List Node -> List Node
                fixedPrevious prior accum nodeList =
                    case nodeList of
                        [] ->
                            accum

                        node_ :: rest ->
                            fixedPrevious (Just node_.ref) ({ node_ | previousSibling = prior } :: accum) rest

                fixedNext next accum nodeList =
                    case nodeList of
                        [] ->
                            accum

                        node_ :: rest ->
                            fixedNext (Just node_.ref) ({ node_ | nextSibling = next } :: accum) rest

                newAddedNodes =
                    addedNodes |> fixedPrevious previousSiblingRef [] |> fixedNext nextSiblingRef []

                removedNodes =
                    getNodeList childMutation.removedNodes domFragment

                newRemovedNodes =
                    List.map (\node_ -> { node_ | parentNode = Nothing, nextSibling = Nothing, previousSibling = Nothing }) removedNodes

                newFirstChild : Maybe Node
                newFirstChild =
                    let
                        listEntryPoint =
                            newPreviousSibling |> MaybeX.orElse (List.head newAddedNodes) |> MaybeX.orElse newNextSibling

                        findFirstChildFrom node_ =
                            case node_.previousSibling of
                                Nothing ->
                                    Just node_

                                Just ref ->
                                    findFirstChildFrom <| getNode ref domFragment
                    in
                    Maybe.andThen findFirstChildFrom listEntryPoint

                newFirstChildRef =
                    Maybe.map (\n -> n.ref) newFirstChild

                domFragment_ =
                    domFragment
                        |> maybeSetNode newPreviousSibling
                        |> maybeSetNode newNextSibling

                domFragment__ =
                    List.foldl (\node_ df -> setNode node_ df) domFragment_ newAddedNodes

                domFragment___ =
                    List.foldl (\node_ df -> setNode node_ df) domFragment__ newRemovedNodes
            in
            if newFirstChildRef /= html.firstChild then
                setNode { node | content = HtmlNode { html | firstChild = newFirstChildRef } } domFragment___

            else
                domFragment___



-- JS Port protocol


type JsMsg
    = JSMutation MutationRecord
    | NewHtmlNode NewHtmlNodeDescriptor
    | NewTextNode NewTextNodeDescriptor
    | RemoveNode NodeRef


decodeJsMsg =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\type_ ->
                Decode.field "data" <|
                    case type_ of
                        "MutationRecord" ->
                            Decode.map JSMutation decodeMutationRecord

                        "NewHtmlNode" ->
                            Decode.map NewHtmlNode decodeNewHtmlNode

                        "NewTextNode" ->
                            Decode.map NewTextNode decodeNewTextNode

                        "RemoveNode" ->
                            Decode.map RemoveNode decodeRemoveNode

                        _ ->
                            Decode.fail ("Unknown message type from Javascript: " ++ type_)
            )


type alias NewHtmlNodeDescriptor =
    { ref : NodeRef
    , kind : String
    , attributes : Attributes
    }


decodeNewHtmlNode =
    Decode.map3 NewHtmlNodeDescriptor
        (Decode.field "ref" decodeNodeRef)
        (Decode.field "tag" Decode.string)
        (Decode.field "attributes" decodeAttributes)


type alias NewTextNodeDescriptor =
    { ref : NodeRef
    , text : String
    }


decodeNewTextNode =
    Decode.map2 NewTextNodeDescriptor
        (Decode.field "ref" decodeNodeRef)
        (Decode.field "text" Decode.string)


decodeRemoveNode =
    Decode.field "ref" decodeNodeRef


type alias JsMsgList =
    List JsMsg


decodeJsMsgList =
    Decode.list decodeJsMsg


port receiveMessage : (Decode.Value -> msg) -> Sub msg


applyJsMessage : JsMsg -> DomFragment -> DomFragment
applyJsMessage msg frag =
    case msg of
        JSMutation mutation ->
            applyMutationRecord mutation frag

        NewHtmlNode html ->
            applyNewHtmlNode html frag

        NewTextNode text_ ->
            applyNewTextNode text_ frag

        RemoveNode ref ->
            applyRemoveNode ref frag


applyNewHtmlNode html frag =
    Dict.insert html.ref
        { ref = html.ref
        , previousSibling = Nothing
        , nextSibling = Nothing
        , parentNode = Nothing
        , content = HtmlNode { kind = html.kind, attributes = html.attributes, firstChild = Nothing }
        }
        frag


applyNewTextNode text_ frag =
    Dict.insert text_.ref
        { ref = text_.ref
        , previousSibling = Nothing
        , nextSibling = Nothing
        , parentNode = Nothing
        , content = Text text_.text
        }
        frag


applyRemoveNode ref frag =
    Dict.remove ref frag



-- errors


logInfo =
    logError


logError message logValue returnValue =
    let
        _ =
            Debug.log message logValue
    in
    returnValue



-- Tree DOM


type TreeNode
    = HtmlTree String Attributes TreeNodeList
    | TextTree String


type alias TreeNodeList =
    List TreeNode



--node =
--    HtmlTree
--div =
--    node "div"
--text =
--    TextTree
--span =
--    node "span"


type ContentEditable
    = ContentEditable TreeNode DomFragment


type Change
    = AppendNodes NodeRef (List TreeNode)
    | RemoveNodes NodeRef (List NodeRef)
    | ChangeText NodeRef String
    | ReplaceNode TreeNode NodeRef
    | ReplaceAttributes Attributes NodeRef


diffNodeLists : TreeNodeList -> NodeRef -> List NodeRef -> DomFragment -> List Change -> List Change
diffNodeLists treeNodes graphParentRef graphRefs graph changes =
    let
        diffLists treeList graphList changes_ =
            case ( treeList, graphList ) of
                ( [], [] ) ->
                    changes_

                ( nodes, [] ) ->
                    appendNodesChange graphParentRef nodes changes_

                ( [], nodes ) ->
                    removeNodesChange graphParentRef nodes changes_

                ( treeNode :: treeRest, graphNodeRef :: graphRest ) ->
                    diffLists treeRest graphRest (diffNodes treeNode graphNodeRef graph changes_)
    in
    List.reverse (diffLists treeNodes graphRefs changes)


appendNodesChange graphParentRef treeNodes changes =
    AppendNodes graphParentRef treeNodes :: changes


removeNodesChange graphParentRef graphNodes changes =
    RemoveNodes graphParentRef graphNodes :: changes


diffNodes treeNode graphNodeRef graph changes =
    let
        graphNode =
            getNode graphNodeRef graph
    in
    case ( treeNode, graphNode.content ) of
        ( TextTree new, Text old ) ->
            if new /= old then
                ChangeText graphNodeRef new :: changes

            else
                changes

        ( HtmlTree kind attributes newChildren, HtmlNode old ) ->
            if kind /= old.kind then
                ReplaceNode treeNode graphNodeRef :: changes

            else
                let
                    changes_ =
                        if attributes /= old.attributes then
                            ReplaceAttributes attributes graphNodeRef :: changes

                        else
                            changes
                in
                diffNodeLists newChildren graphNodeRef (children old graph) graph changes_

        ( old, new ) ->
            ReplaceNode treeNode graphNodeRef :: changes


graphToTree graph =
    let
        handleNode graphRef =
            let
                node =
                    getNode graphRef graph
            in
            case node.content of
                Text data ->
                    TextTree data

                HtmlNode html ->
                    HtmlTree html.kind html.attributes (List.map handleNode (children html graph))
    in
    handleNode 0


filterTree tree =
    case tree of
        TextTree value ->
            tree

        HtmlTree kind attributes kids ->
            case kind of
                "b" ->
                    HtmlTree "span" attributes (List.map filterTree kids)

                _ ->
                    HtmlTree kind attributes (List.map filterTree kids)



-- Harness


type Msg
    = JsMessages Decode.Value


type alias Model =
    { frag : DomFragment }


init : () -> ( Model, Cmd Msg )
init flags =
    let
        ( frag, rootRef ) =
            newDomFragment (HtmlNode { kind = "div", attributes = Dict.empty, firstChild = Nothing })

        --frag_ =
        --    frag
        --        |> addNode (rootRef + 1) (Text "hello world")
        --        |> addNode (rootRef + 2) (Text " Middle world")
        --        |> addNode (rootRef + 3) (Text " End world")
        --        |> addNode (rootRef + 4) (HtmlNode { kind = "div", attributes = Dict.empty, firstChild = Nothing })
        --        |> appendChild (rootRef + 1) rootRef
        --        |> appendChild (rootRef + 2) rootRef
        --        |> appendChild (rootRef + 4) rootRef
        --        |> appendChild (rootRef + 3) (rootRef + 4)
    in
    ( { frag = frag }, Cmd.none )


update msg model =
    case msg of
        JsMessages value ->
            case Decode.decodeValue decodeJsMsgList value of
                Ok msgList ->
                    let
                        frag =
                            List.foldl applyJsMessage model.frag msgList

                        tree =
                            graphToTree frag

                        filteredTree =
                            filterTree tree

                        _ =
                            Debug.log "Here's the diff with self " (diffNodes filteredTree 0 frag [])
                    in
                    ( { model | frag = frag }, Cmd.none )

                Err err ->
                    logError "Failed to decode message from JS: " (Decode.errorToString err) ( model, Cmd.none )


subscriptions model =
    receiveMessage JsMessages


view : Model -> H.Html Msg
view model =
    H.div [] [ viewNode (getNode rootNodeRef model.frag) model.frag ]


viewNode : Node -> DomFragment -> H.Html Msg
viewNode node domFragment =
    let
        viewChildList childRef result =
            case childRef of
                Nothing ->
                    List.reverse result

                Just ref_ ->
                    let
                        child =
                            getNode ref_ domFragment
                    in
                    viewChildList child.nextSibling (viewNode child domFragment :: result)
    in
    case node.content of
        Text value ->
            H.text value

        HtmlNode html ->
            H.node html.kind [] (viewChildList html.firstChild [])


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
