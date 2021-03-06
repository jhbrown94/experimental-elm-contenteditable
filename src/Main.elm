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


module Main exposing (..)

import Browser
import Editable
import Element as E
import Element.Background as EBackground
import Element.Border as EB
import Element.Input as EI
import Html
import Html.Attributes
import Html.Events
import HtmlLite as Lite
import Json.Decode as Decode
import Json.Encode as Encode


type Msg
    = Edited Editable.State
    | RemoveAttributes


type alias Model =
    { userAgent : String, editorState : Editable.State }


highlightColor =
    E.rgb 0.4 0.9 0.9


buttonColor =
    E.rgb 0.9 0.9 0.9


view : Model -> Html.Html Msg
view { userAgent, editorState } =
    E.layout [ E.width E.fill, E.height E.fill ] <|
        E.column
            [ E.width E.fill, E.padding 10, E.spacing 10, EB.width 1, E.height E.fill ]
            [ E.paragraph [ E.width E.fill ] [ E.text <| "User agent: " ++ userAgent ]
            , E.text <| "Selection: " ++ (editorState.selection |> Debug.toString)
            , EI.button [ EB.width 1, EB.rounded 4, EBackground.color <| buttonColor ] { onPress = Just RemoveAttributes, label = E.el [ E.padding 4 ] <| E.text "Remove attributes" }
            , E.row [ E.width E.fill, E.spacing 12, E.padding 12, E.height E.fill ]
                [ E.column [ E.width E.fill, E.spacing 4, E.alignTop ]
                    [ E.text "Edit in here"
                    , E.el [ E.alignTop, E.width E.fill, EB.width 1, E.padding 4 ] <|
                        E.html
                            (Editable.editable
                                [ Html.Attributes.style "display" "flex" ]
                                Edited
                                editorState
                            )
                    ]
                , E.column [ E.width E.fill, E.scrollbarX, E.spacing 4, E.alignTop, E.height E.fill ]
                    [ E.text "HTML structure as seen in Elm"
                    , E.column [ E.width E.fill, EB.width 1, E.scrollbars, E.padding 4, E.height E.fill ] <|
                        viewNodes editorState
                    ]
                ]
            ]


viewNodes : Editable.State -> List (E.Element Msg)
viewNodes state =
    let
        viewAttributes attrs =
            List.map (\( name, value ) -> name ++ "=\"" ++ value ++ "\"") attrs |> String.join " "

        viewNode ( node, selection ) =
            case node of
                Just (Lite.HtmlNode tag attrs children) ->
                    E.column [ E.width E.fill ]
                        [ E.text <| "<" ++ tag ++ " " ++ viewAttributes attrs ++ ">\n"
                        , E.column [ E.width E.fill, E.paddingEach { left = 16, right = 0, top = 0, bottom = 0 } ] <|
                            viewNodes { selection = selection, html = children }
                        , E.text <| "</" ++ tag ++ ">\n"
                        ]

                Just (Lite.TextNode text) ->
                    E.paragraph [ E.width E.fill ]
                        ([ E.text "#text(" ]
                            ++ (case selection of
                                    Editable.NoSelection ->
                                        [ E.text text ]

                                    Editable.Caret i ->
                                        let
                                            index =
                                                List.head i |> Maybe.withDefault 0

                                            pre =
                                                String.left index text

                                            post =
                                                String.dropLeft index text
                                        in
                                        [ E.text pre
                                        , E.el [ E.width (E.px 8), E.height (E.px 16), EBackground.color highlightColor ] E.none
                                        , E.text post
                                        ]

                                    Editable.LeftFocus left right ->
                                        let
                                            leftOffset =
                                                List.head left |> Maybe.withDefault 0

                                            rightOffset =
                                                List.head right |> Maybe.withDefault (String.length text)

                                            r =
                                                String.dropLeft rightOffset text

                                            l =
                                                String.left leftOffset text

                                            m =
                                                String.left rightOffset text |> String.dropLeft leftOffset
                                        in
                                        [ E.text l
                                        , E.el [ EBackground.color highlightColor ] <| E.text m
                                        , E.text r
                                        ]

                                    Editable.RightFocus left right ->
                                        let
                                            leftOffset =
                                                List.head left |> Maybe.withDefault 0

                                            rightOffset =
                                                List.head right |> Maybe.withDefault (String.length text)

                                            r =
                                                String.dropLeft rightOffset text

                                            l =
                                                String.left leftOffset text

                                            m =
                                                String.left rightOffset text |> String.dropLeft leftOffset
                                        in
                                        [ E.text l
                                        , E.el [ EBackground.color highlightColor ] <| E.text m
                                        , E.text r
                                        ]
                               )
                            ++ [ E.text ")" ]
                        )

                _ ->
                    E.none
    in
    List.map (\i -> Editable.descendState i state |> viewNode) (List.range 0 (List.length state.html - 1))



-- loggingDecoder is from https://thoughtbot.com/blog/debugging-dom-event-handlers-in-elm


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
                            |> Decode.fail
            )


demoFilter htmlList =
    List.map
        (\n ->
            case n of
                Lite.TextNode value ->
                    Lite.TextNode (String.replace "teh " "the " value)

                Lite.HtmlNode k a c ->
                    Lite.HtmlNode k a (demoFilter c)
        )
        htmlList


removeAttributes htmlList =
    List.map
        (\n ->
            case n of
                Lite.TextNode value ->
                    n

                Lite.HtmlNode k a c ->
                    Lite.HtmlNode k [] (removeAttributes c)
        )
        htmlList


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ editorState } as model) =
    case msg of
        Edited state ->
            ( { model | editorState = state |> Editable.mapHtml demoFilter }, Cmd.none )

        RemoveAttributes ->
            ( { model | editorState = model.editorState |> Editable.mapHtml removeAttributes }, Cmd.none )


init : String -> ( Model, Cmd Msg )
init flag =
    ( Model flag
        (Editable.init
            [ Lite.HtmlNode "i" [] [ Lite.TextNode "hello world from Elm" ]
            ]
        )
    , Cmd.none
    )


main =
    Browser.element
        { view = view
        , update = update
        , init = init
        , subscriptions = \model -> Sub.none
        }
