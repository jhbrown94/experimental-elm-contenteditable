module Editable exposing (..)

import Browser
import Html
import Html.Attributes
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode


type alias State =
    { html : HtmlList
    , selection : Selection
    , dirty : Bool
    }


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


type Selection
    = NoSelection
    | Caret HtmlPosition
    | Range HtmlPosition HtmlPosition


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


view state =
    Html.node "custom-editable"
        [ Html.Events.on "edited"
            (Decode.map2 Edited
                (loggingDecoder (Decode.field "detail" (Decode.field "html" decodeHtmlList)))
                (loggingDecoder (Decode.field "detail" (Decode.field "selection" decodeSelection)))
            )
        , Html.Attributes.attribute "dirty"
            (if state.dirty then
                "true"

             else
                "false"
            )
        , Html.Attributes.attribute "selection" (Encode.encode 0 (encodeSelection state.selection))
        ]
        (listToHtml state.html)


loggingDecoder realDecoder =
    Decode.value
        |> Decode.andThen
            (\event ->
                case Decode.decodeValue realDecoder event of
                    Ok decoded ->
                        Decode.succeed decoded

                    Err error ->
                        error
                            |> Decode.errorToString
                            |> Debug.log "decoding error"
                            |> Decode.fail
            )


decodeSelection =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\type_ ->
                case type_ of
                    "None" ->
                        Decode.succeed NoSelection

                    "Caret" ->
                        Decode.map Caret (Decode.field "focus" decodeHtmlPosition)

                    "Range" ->
                        Decode.map2 Range (Decode.field "anchor" decodeHtmlPosition) (Decode.field "focus" decodeHtmlPosition)

                    _ ->
                        Decode.fail "Failed to decode selection"
            )


encodeSelection selection =
    case selection of
        NoSelection ->
            Encode.object [ ( "type", Encode.string "None" ) ]

        Caret focus ->
            Encode.object [ ( "type", Encode.string "Caret" ), ( "focus", encodeHtmlPosition focus ), ( "anchor", encodeHtmlPosition focus ) ]

        Range anchor focus ->
            Encode.object [ ( "type", Encode.string "Range" ), ( "focus", encodeHtmlPosition focus ), ( "anchor", encodeHtmlPosition anchor ) ]


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


type Msg
    = Edited HtmlList Selection


demoFilter htmlList =
    List.map
        (\n ->
            case n of
                Text value ->
                    Text (String.replace "teh " "the " value)

                Element k a c ->
                    Element k a (demoFilter c)
        )
        htmlList


update msg state =
    case msg of
        Edited htmlList selection ->
            let
                newHtml =
                    htmlList |> demoFilter

                dirty =
                    htmlList /= newHtml

                _ =
                    if dirty then
                        Debug.log "dirty" dirty

                    else
                        dirty
            in
            { state | html = newHtml, selection = selection, dirty = dirty }


main =
    Browser.sandbox
        { view = view
        , update = update
        , init = State [ Element "i" [] [ Text "hello world from Elm" ] ] NoSelection True
        }
