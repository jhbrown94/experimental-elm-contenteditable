module Editable exposing (..)

import Json.Decode as Decode
import Json.Encode as Encode


type alias State =
    { html : Html
    , selection : Selection
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


type alias Selection =
    { start : HtmlPosition
    , end : HtmlPosition
    }


type alias HtmlPosition =
    List Int



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


encodeHtmlElement tagName attributes children =
    Encode.object [ ( "nodeName", Encode.string tagName ), ( "attributes", encodeAttributes attributes ), ( "childNodes", encodeHtmlList children ) ]


decodeHtmlElement =
    Decode.map3 Element
        (Decode.field "tagName" Decode.string)
        (Decode.field "attributes" decodeAttributes)
        (Decode.field "childNodes" decodeHtmlList)


encodeAttributes attributes =
    Encode.list encodeAttribute attributes


decodeAttributes =
    Decode.list decodeAttribute


encodeAttribute attribute =
    Encode.object [ ( "name", Encode.string attribute.name ), ( "value", Encode.string attribute.value ) ]


decodeAttribute =
    Decode.map2 Attribute (Decode.field "name" Decode.string) (Decode.field "value" Decode.string)


encodeHtmlList htmlList =
    Encode.list encodeHtml htmlList


decodeHtmlList =
    Decode.list decodeHtml


encodeHtmlText text =
    Encode.object [ ( "nodeName", Encode.string "#text" ), ( "data", Encode.string text ) ]



-- https://developer.mozilla.org/en-US/docs/Web/API/CharacterData


decodeHtmlText =
    Decode.map Text (Decode.field "data" Decode.string)


encodeHtml html =
    case html of
        Element tagName attributes children ->
            encodeHtmlElement tagName attributes children

        Text text ->
            encodeHtmlText text


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
