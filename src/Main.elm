port module Main exposing (main)

import Browser
import Html
import Html.Attributes
import Html.Parser as Parser exposing (..)
import Html.Parser.Util
import Json.Decode as Json



-- import Keyboard.Event


port setContent : ( String, String ) -> Cmd msg


port receiveContent : (String -> msg) -> Sub msg


fixText html =
    case html of
        Text string ->
            Text (String.replace "*" "..." string)

        Element kind attrs children ->
            Element kind attrs (List.map fixText children)

        Comment x ->
            html


exampleDoc =
    Element "div"
        []
        [ Element "p" [] [ Text "Begin here" ]
        , Element "ul"
            []
            [ Element "li" [] [ Text "first item" ]
            , Element "ul"
                []
                [ Element "li" [] [ Text "next item" ]
                , Element "li" [] [ Text "Nested item" ]
                ]
            ]
        , Text "End here"
        , Text ". Finale."
        ]


view model =
    Html.div
        []
        [ Html.text "this is straight from Elm" ]


type alias Model =
    Node


type Msg
    = NoOp
    | SetContent
    | ReceiveContent String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetContent ->
            ( model, setContent ( "editor", nodeToString model ) )

        ReceiveContent string ->
            let
                newModel =
                    string
                        |> Parser.run
                        |> Result.withDefault [ Text "Parse failed" ]
                        |> List.head
                        |> Maybe.withDefault (Text "Parse failed")
                        |> fixText
            in
            if model == newModel then
                ( model, Cmd.none )

            else
                update SetContent newModel

        NoOp ->
            ( model, Cmd.none )


type alias Flags =
    ()


subscriptions model =
    receiveContent ReceiveContent


main : Program Flags Model Msg
main =
    Browser.element
        { init = \_ -> ( exampleDoc, setContent ( "editor", nodeToString exampleDoc ) )
        , subscriptions = subscriptions
        , view = view
        , update = update
        }
