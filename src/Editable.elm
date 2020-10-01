-- Copyright 2020, Jeremy H. Brown
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- 3. Neither the name of the copyright holder nor the names of its
-- contributors may be used to endorse or promote products derived from this
-- software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.


module Editable exposing
    ( Selection(..)
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
import HtmlLite as Lite exposing (..)
import Json.Decode as Decode
import Json.Encode as Encode



-- Put an editable into the view


editable : List (Html.Attribute msg) -> (State -> msg) -> State -> Html.Html msg
editable attrs msg state =
    Html.node "custom-editable"
        ([ Html.Attributes.property "state" (encodeState state)
         , Html.Events.stopPropagationOn
            "edited"
            (Decode.map2 Tuple.pair
                (Decode.map (Debug.log "Decoded event" >> msg)
                    (Decode.map2 State
                        (Decode.field "detail" (Decode.field "html" decodeDomHtmlList))
                        (Decode.field "detail" (Decode.field "selection" decodeSelection))
                    )
                )
                (Decode.succeed True)
            )
         ]
            ++ attrs
        )
        []


encodeState state =
    Encode.object [ ( "html", Lite.encodeHtmlList state.html ), ( "selection", encodeSelection state.selection ) ]



-- Initial state for an editable


init : List Html -> State
init htmlList =
    { html = htmlList, selection = NoSelection }



-- State and operators


type alias State =
    { html : List Html
    , selection : Selection
    }



-- Gives you back the index'th child node, and as much of the selection as is visible from that node.


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
        HtmlNode tag attrs children ->
            prefix ++ "<" ++ tag ++ attributesToString indent attrs ++ ">\n" ++ htmlListToString (indent + 1) children ++ prefix ++ "</" ++ tag ++ ">\n"

        TextNode text ->
            prefix ++ text ++ "\n"


htmlListToString : Int -> List Html -> String
htmlListToString indent htmlList =
    List.foldl (\n a -> a ++ htmlToString indent n) "" htmlList



-- Html for CE's.


nodeToHtml html =
    case html of
        HtmlNode tag attributes children ->
            Html.node tag (List.map (\( name, value ) -> Html.Attributes.attribute name value) attributes) (listToHtml children)

        TextNode text ->
            Html.text text


listToHtml htmlList =
    List.map nodeToHtml htmlList


decodeDomHtmlNode =
    Decode.map3 HtmlNode
        (Decode.field "tagName" Decode.string)
        (Decode.field "attributes" decodeAttributes)
        (Decode.field "childNodes" decodeDomHtmlList)


decodeAttributes =
    Decode.keyValuePairs decodeAttribute |> Decode.map (List.map Tuple.second)


decodeAttribute =
    Decode.map2 Tuple.pair (Decode.field "name" Decode.string) (Decode.field "value" Decode.string)


decodeDomHtmlList =
    Decode.keyValuePairs decodeHtml |> Decode.map (List.map Tuple.second)


decodeTextNode =
    Decode.map TextNode (Decode.field "data" Decode.string)


decodeHtml =
    Decode.field "nodeName" Decode.string
        |> Decode.andThen
            (\nodeName ->
                case nodeName of
                    "#text" ->
                        decodeTextNode

                    -- TODO: there could be non-tagname things, see https://developer.mozilla.org/en-US/docs/Web/API/Node/nodeName
                    tagName ->
                        decodeDomHtmlNode
            )



-- Attributes for the Html


attributeToString ( name, value ) =
    name ++ " = \"" ++ value ++ "\""


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



-- CERange and operators -- this is what custom-editable.js talks in terms of -- focus and anchor rather than left and right.


type alias CERange =
    { anchor : HtmlPosition, focus : HtmlPosition }


decodeCERange =
    Decode.map2 CERange (Decode.field "anchor" decodeHtmlPosition) (Decode.field "focus" decodeHtmlPosition)


encodeCERange range =
    Encode.object [ ( "anchor", encodeHtmlPosition range.anchor ), ( "focus", encodeHtmlPosition range.focus ) ]
