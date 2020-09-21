module Editable exposing
    ( Html(..)
    , Selection(..)
    , State
    , descendState
    , editable
    , getHtml
    , htmlListToString
    , htmlToString
    , init
    , mapHtml
    )

import Browser
import Html
import Html.Attributes
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode



-- State for a content-editable


type alias State =
    { html : HtmlList
    , selection : Selection
    }


descendState : Int -> State -> ( Maybe Html, Selection )
descendState index state =
    ( state.html |> List.drop index |> List.head, descendSelection index state.selection )


getHtml state =
    state.html


mapHtml f state =
    { state | html = f state.html }


htmlToString indent html =
    let
        prefix =
            String.repeat indent "    "
    in
    case html of
        Element kind attrs children ->
            prefix ++ "<" ++ kind ++ attributesToString indent attrs ++ ">\n" ++ htmlListToString (indent + 1) children ++ prefix ++ "</" ++ kind ++ ">\n"

        Text text ->
            prefix ++ text ++ "\n"


htmlListToString : Int -> HtmlList -> String
htmlListToString indent htmlList =
    List.foldl (\n a -> a ++ htmlToString indent n) "" htmlList



-- Html for CE's.


type Html
    = Element Kind Attributes HtmlList
    | Text String


type alias Kind =
    String



-- Attributes for the Html


type alias Attribute =
    { name : String
    , value : String
    }


type alias Attributes =
    List Attribute


type alias HtmlList =
    List Html


attributeToString attr =
    attr.name ++ " = \"" ++ attr.value ++ "\""


attributesToString indent attrs =
    let
        prefix =
            String.repeat indent "    " ++ "  "
    in
    case attrs of
        [] ->
            ""

        [ a ] ->
            " " ++ attributeToString a

        many ->
            List.map attributeToString many |> List.foldl (\s a -> a ++ "\n" ++ prefix ++ s) ""



-- Selection and operators


type Selection
    = NoSelection
    | Caret HtmlPosition
    | LeftFocus HtmlPosition HtmlPosition
    | RightFocus HtmlPosition HtmlPosition


decodeSelection =
    Decode.oneOf
        [ decodeCERange
            |> Decode.andThen
                (\cerange ->
                    case cmpHtmlPosition cerange.anchor cerange.focus of
                        Equal ->
                            Decode.succeed <| Caret cerange.focus

                        GreaterThan ->
                            Decode.succeed <| LeftFocus cerange.focus cerange.anchor

                        LessThan ->
                            Decode.succeed <| RightFocus cerange.anchor cerange.focus
                )
        , Decode.succeed NoSelection
        ]


encodeSelection selection =
    case selection of
        NoSelection ->
            Encode.null

        Caret pos ->
            encodeCERange <| { anchor = pos, focus = pos }

        LeftFocus left right ->
            encodeCERange { anchor = right, focus = left }

        RightFocus left right ->
            encodeCERange { anchor = left, focus = right }


descendSelection index selection =
    case selection of
        LeftFocus left right ->
            descendRange index left right |> Maybe.map (\( l, r ) -> LeftFocus l r) |> Maybe.withDefault NoSelection

        RightFocus left right ->
            descendRange index left right |> Maybe.map (\( l, r ) -> RightFocus l r) |> Maybe.withDefault NoSelection

        Caret (i :: rest) ->
            if i == index then
                Caret rest

            else
                NoSelection

        Caret [] ->
            NoSelection

        NoSelection ->
            selection



-- HtmlPosition and operators


type alias HtmlPosition =
    List Int


decodeHtmlPosition =
    Decode.list Decode.int


encodeHtmlPosition pos =
    Encode.list Encode.int pos


type Comparison
    = GreaterThan
    | LessThan
    | Equal


cmpHtmlPosition left right =
    case ( left, right ) of
        ( l :: lrest, r :: rrest ) ->
            if l == r then
                cmpHtmlPosition lrest rrest

            else if l < r then
                LessThan

            else
                GreaterThan

        ( n :: lrest, [] ) ->
            if n > 0 then
                GreaterThan

            else
                cmpHtmlPosition lrest []

        ( [], n :: rrest ) ->
            if n > 0 then
                LessThan

            else
                cmpHtmlPosition rrest []

        ( [], [] ) ->
            Equal



-- CERange and operators -- this is what custom-editable.js talks in terms of


type alias CERange =
    { anchor : HtmlPosition, focus : HtmlPosition }


decodeCERange =
    Decode.map2 CERange (Decode.field "anchor" decodeHtmlPosition) (Decode.field "focus" decodeHtmlPosition)


encodeCERange range =
    Encode.object [ ( "anchor", encodeHtmlPosition range.anchor ), ( "focus", encodeHtmlPosition range.focus ) ]



-- Descending a selection range


descendRange : Int -> HtmlPosition -> HtmlPosition -> Maybe ( HtmlPosition, HtmlPosition )
descendRange index left right =
    case ( left, right ) of
        ( l :: lrest, r :: rrest ) ->
            if index == l then
                if index == r then
                    Just <| ( lrest, rrest )

                else
                    Just <| ( lrest, [] )

            else if index == r then
                Just <| ( [], rrest )

            else if index > l && index < r then
                Just <| ( [], [] )

            else
                Nothing

        ( l :: lrest, [] ) ->
            if index == l then
                Just <| ( lrest, [] )

            else if index > l then
                Just <| ( [], [] )

            else
                Nothing

        ( [], r :: rrest ) ->
            if index == r then
                Just <| ( [], rrest )

            else if index < r then
                Just <| ( [], [] )

            else
                Nothing

        ( [], [] ) ->
            Just <| ( [], [] )



-- Ill-sorted stuff below here TODO organize this


nodeToHtml html =
    case html of
        Element kind attributes children ->
            Html.node kind (List.map (\{ name, value } -> Html.Attributes.attribute name value) attributes) (listToHtml children)

        Text text ->
            Html.text text


listToHtml htmlList =
    List.map nodeToHtml htmlList



-- Future TODO: lots of operations that modify the HTML and preserve/update the selection appropriately
-- removeSelection
-- replaceSelection
-- insertAfterCaret
-- insertBeforeCaret
-- nestSelectionIn - creates a new node and puts the selection as a child of that node, e.g. for adding styling to the entire selection
-- normalize (merges adjacent text nodes, and optionally spans with identical attributes, and MAYBE even divs ...?  maybe there's a variant that takes a function to assess mergeability)
-- collapse (replace a parent node with its children, e.g. removing a styling node)
-- possibly zipper-type operations so that we can traverse and modify in some coherent manner
-- Version 1: shovel the entire HTML tree over the port on every call.  If people use this, we'll think about efficiency (diffs & vdom & etc.) down the road.
--encodeHtmlElement tagName attributes children =
--    Encode.object [ ( "nodeName", Encode.string tagName ), ( "attributes", encodeAttributes attributes ), ( "childNodes", encodeHtmlList children ) ]


decodeHtmlElement =
    Decode.map3 Element
        (Decode.field "tagName" Decode.string)
        (Decode.field "attributes" decodeAttributes)
        (Decode.field "childNodes" decodeHtmlList)



--encodeAttributes attributes =
--    Encode.list encodeAttribute attributes


decodeAttributes =
    Decode.keyValuePairs decodeAttribute |> Decode.map (List.map Tuple.second)



--encodeAttribute attribute =
--    Encode.object [ ( "name", Encode.string attribute.name ), ( "value", Encode.string attribute.value ) ]


decodeAttribute =
    Decode.map2 Attribute (Decode.field "name" Decode.string) (Decode.field "value" Decode.string)



--encodeHtmlList htmlList =
--    Encode.list encodeHtml htmlList


decodeHtmlList =
    Decode.keyValuePairs decodeHtml |> Decode.map (List.map Tuple.second)



--encodeHtmlText text =
--    Encode.object [ ( "nodeName", Encode.string "#text" ), ( "data", Encode.string text ) ]
-- https://developer.mozilla.org/en-US/docs/Web/API/CharacterData


decodeHtmlText =
    Decode.map Text (Decode.field "data" Decode.string)



--encodeHtml html =
--    case html of
--        Element tagName attributes children ->
--            encodeHtmlElement tagName attributes children
--        Text text ->
--            encodeHtmlText text


decodeHtml =
    Decode.field "nodeName" Decode.string
        |> Decode.andThen
            (\nodeName ->
                case nodeName of
                    "#text" ->
                        decodeHtmlText

                    -- TODO: there could be non-tagname things, see https://developer.mozilla.org/en-US/docs/Web/API/Node/nodeName
                    tagName ->
                        decodeHtmlElement
            )


editable attrs msg state =
    Html.node "custom-editable"
        ([ Html.Events.stopPropagationOn
            "edited"
            (Decode.map2 Tuple.pair
                (Decode.map msg
                    (Decode.map2 State
                        (Decode.field "detail" (Decode.field "html" decodeHtmlList))
                        (Decode.field "detail" (Decode.field "selection" decodeSelection))
                    )
                )
                (Decode.succeed True)
            )
         , Html.Attributes.attribute "selection" (Encode.encode 0 (encodeSelection state.selection))
         ]
            ++ attrs
        )
        (listToHtml (Debug.log "State html" state.html))


init : HtmlList -> State
init htmlList =
    { html = htmlList, selection = NoSelection }
