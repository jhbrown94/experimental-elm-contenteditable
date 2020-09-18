module Main exposing (..)

import Browser
import Editable
import Element as E
import Element.Border as EB
import Html
import Html.Attributes
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode


type alias Msg =
    Editable.Msg


type alias Model =
    { userAgent : String, editable : Editable.Model }


view : Model -> Html.Html Msg
view { userAgent, editable } =
    E.layout [ E.width E.fill ] <|
        E.column
            [ E.width E.fill, E.padding 10, EB.width 1 ]
            [ E.text <| "User agent: " ++ userAgent
            , E.row [ E.width E.fill, E.spacing 12, E.padding 12 ]
                [ E.el [ E.alignTop, E.width E.fill, EB.width 1, E.padding 4 ] <|
                    E.html
                        (Editable.view
                            [ Html.Attributes.style "display" "flex" ]
                            editable
                        )
                , E.el [ E.width E.fill, EB.width 1 ] <|
                    E.html <|
                        Html.pre [] [ Html.text <| Editable.htmlListToString 0 (Editable.getHtml editable) ]
                ]
            ]



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
                            |> Debug.log "decoding error"
                            |> Decode.fail
            )


demoFilter htmlList =
    List.map
        (\n ->
            case n of
                Editable.Text value ->
                    Editable.Text (String.replace "teh " "the " value)

                Editable.Element k a c ->
                    Editable.Element k a (demoFilter c)
        )
        htmlList


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ editable } as model) =
    ( { model | editable = Editable.update msg editable |> Editable.mapHtml demoFilter }, Cmd.none )


init : String -> ( Model, Cmd Msg )
init flag =
    ( Model flag
        (Editable.init
            [ Editable.Element "i" [] [ Editable.Text "hello world from Elm" ]
            ]
        )
    , Cmd.none
    )
        |> Debug.log "test"


main =
    Browser.element
        { view = view
        , update = update
        , init = init
        , subscriptions = \model -> Sub.none
        }
