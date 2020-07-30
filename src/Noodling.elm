module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes as Attributes exposing (contenteditable, style)
import Html.Events as Events
import Json.Decode as Json


type alias Model =
    List String


type Msg
    = Input String
    | Keydown
    | MouseDown


update : Msg -> Model -> Model
update msg model =
    case msg of
        Input s ->
            List.append model [ "input (" ++ s ++ ") " ]

        Keydown ->
            List.append model [ "Keydown " ]

        MouseDown ->
            List.append model [ "mouseDown " ]


view model =
    div [ style "width" "100%", style "height" "100%" ]
        [ div
            [ Attributes.id "editor"
            , style "width" "640px"
            , style "height" "480px"
            , contenteditable True
            , style "border" "1px"
            , style "borderColor" "black"
            , onInput Input

            --, onMouseDown MouseDown
            --, onKeydown Keydown
            ]
            [ text "help me" ]
        , div
            [ style "width" "640px"
            , style "border" "1px"
            , style "borderColor" "black"
            ]
            (text "Log:"
                :: List.map text model
            )
        ]


main =
    Browser.sandbox
        { init = []
        , view = view
        , update = update
        }


onInput msg =
    Events.preventDefaultOn "input" (Json.map (msg >> alwaysPreventDefault) (Json.at [ "target", "childNodes" ] (Json.index 0 Json.string)))


onKeydown : msg -> Attribute msg
onKeydown msg =
    Events.preventDefaultOn "keydown" (Json.map alwaysPreventDefault (Json.succeed msg))


onMouseDown msg =
    Events.preventDefaultOn "mousedown" (Json.map alwaysPreventDefault (Json.succeed msg))


alwaysPreventDefault : msg -> ( msg, Bool )
alwaysPreventDefault msg =
    ( msg, True )
