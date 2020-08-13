module HtmlFromJs exposing (..)

import Browser
import Dict
import Html as H
import Html.Attributes as HA
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
    , attributes : Dict.Dict String String
    , firstChild : Maybe NodeRef
    }


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


type Mutation
    = AttributeMutation String (Maybe String)
    | CharacterData String
    | ChildListMutation ChildListRep


type alias MutationRecord =
    { target : NodeRef
    , mutation : Mutation
    }


type alias ChildListRep =
    { addedNodes : List NodeRef
    , removedNodes : List NodeRef
    , previousSibling : Maybe NodeRef
    , nextSibling : Maybe NodeRef
    }



-- Applications


applyMutationRecord { target, mutation } domFragment =
    let
        node =
            getNode target domFragment
    in
    case ( node.content, mutation ) of
        ( Text _, AttributeMutation _ _ ) ->
            logError "Trying to change attribute on a text node" ( node, mutation ) domFragment

        ( HtmlNode html, AttributeMutation name (Just value) ) ->
            Dict.insert target { node | content = HtmlNode { html | attributes = Dict.insert name value html.attributes } } domFragment

        ( HtmlNode html, AttributeMutation name Nothing ) ->
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



-- errors


logError message logValue returnValue =
    let
        _ =
            Debug.log message logValue
    in
    returnValue



-- Harness


type Msg
    = NoOp


type alias Model =
    { frag : DomFragment }


init : () -> ( Model, Cmd Msg )
init flags =
    let
        ( frag, rootRef ) =
            newDomFragment (HtmlNode { kind = "div", attributes = Dict.empty, firstChild = Nothing })

        frag_ =
            frag
                |> addNode (rootRef + 1) (Text "hello world")
                |> addNode (rootRef + 2) (Text " Middle world")
                |> addNode (rootRef + 3) (Text " End world")
                |> addNode (rootRef + 4) (HtmlNode { kind = "div", attributes = Dict.empty, firstChild = Nothing })
                |> appendChild (rootRef + 1) rootRef
                |> appendChild (rootRef + 2) rootRef
                |> appendChild (rootRef + 4) rootRef
                |> appendChild (rootRef + 3) (rootRef + 4)
    in
    ( { frag = frag_ }, Cmd.none )


update msg model =
    ( model, Cmd.none )


subscriptions model =
    Sub.none


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
