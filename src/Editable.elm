module Editable exposing
    ( Html(..)
    , Model
    , Msg(..)
    , getHtml
    , htmlListToString
    , htmlToString
    , init
    , mapHtml
    , update
    , view
    )

import Browser
import Html
import Html.Attributes
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode


type Model
    = Model State


type alias State =
    { html : HtmlList
    , selection : Maybe Range
    }


getHtml (Model state) =
    state.html


mapHtml f (Model state) =
    Model { state | html = f state.html }


type Html
    = Element Kind Attributes HtmlList
    | Text String


type alias Kind =
    String


type alias Attribute =
    { name : String
    , value : String
    }


type alias Attributes =
    List Attribute


type alias HtmlList =
    List Html


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


type alias Range =
    { start : HtmlPosition, end : HtmlPosition }


type alias HtmlPosition =
    List Int


listToHtml htmlList =
    List.map nodeToHtml htmlList


nodeToHtml html =
    case html of
        Element kind attributes children ->
            Html.node kind (List.map (\{ name, value } -> Html.Attributes.attribute name value) attributes) (listToHtml children)

        Text text ->
            Html.text text


decodeOptionalRange =
    Decode.nullable decodeRange


decodeRange =
    Decode.map2 Range (Decode.field "start" decodeHtmlPosition) (Decode.field "end" decodeHtmlPosition)


encodeOptionalRange range =
    range |> Maybe.map encodeRange |> Maybe.withDefault Encode.null


encodeRange range =
    Encode.object [ ( "start", encodeHtmlPosition range.start ), ( "end", encodeHtmlPosition range.end ) ]


decodeHtmlPosition =
    Decode.list Decode.int


encodeHtmlPosition pos =
    Encode.list Encode.int pos



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


view (Model state) =
    Html.node "custom-editable"
        [ Html.Attributes.style "width" "100%"
        , Html.Attributes.style "height" "100%"
        , Html.Events.stopPropagationOn
            "edited"
            (Decode.map2 Tuple.pair
                (Decode.map2 Edited
                    (Decode.field "detail" (Decode.field "html" decodeHtmlList))
                    (Decode.field "detail" (Decode.field "selection" decodeOptionalRange))
                )
                (Decode.succeed True)
            )
        , Html.Attributes.attribute "selection" (Encode.encode 0 (encodeOptionalRange state.selection))
        ]
        (listToHtml (Debug.log "State html" state.html))


update : Msg -> Model -> Model
update msg (Model state) =
    case msg of
        Edited htmlList selection ->
            Model { state | html = htmlList, selection = selection }


init : HtmlList -> Model
init htmlList =
    Model { html = htmlList, selection = Nothing }


type Msg
    = Edited HtmlList (Maybe Range)
