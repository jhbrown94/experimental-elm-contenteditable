module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes as Attributes exposing (contenteditable, style)
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Json
import Keyboard.Event


type alias KeyedList =
    List ( String, Document )


type Document
    = Text String
    | Paragraph KeyedList
    | Sequence KeyedList
    | Bullets KeyedList


exampleDoc =
    Sequence
        [ ( "1", Paragraph [ ( "a", Text "Begin here" ) ] )
        , ( "2"
          , Bullets
                [ ( "b", Text "first item" )
                , ( "c"
                  , Sequence
                        [ ( "d", Text "next item" )
                        , ( "e", Bullets [ ( "f", Text "Nested item" ) ] )
                        ]
                  )
                ]
          )
        , ( "3", Text "End here" )
        , ( "4", Text ". Finale." )
        ]


addBullet : Document -> Document
addBullet document =
    let
        recurse list =
            List.map (Tuple.mapSecond addBullet) list
    in
    case document of
        Bullets list ->
            Bullets <| List.append (recurse list) [ ( "QQQ", Text "Bullet added." ) ]

        Sequence list ->
            Sequence (recurse list)

        Paragraph list ->
            Paragraph (recurse list)

        Text s ->
            document


viewDocument : Document -> Html Msg
viewDocument document =
    let
        recurse list =
            List.map (Tuple.mapSecond viewDocument) list
    in
    case document of
        Text s ->
            text s

        Sequence list ->
            Keyed.node "div" [] (recurse list)

        Paragraph list ->
            Keyed.node "p" [] (recurse list)

        Bullets list ->
            Keyed.ul [] (recurse list |> List.map (Tuple.mapSecond (\x -> li [] [ x ])))


onKeydown =
    Events.preventDefaultOn "keydown" (Keyboard.Event.decodeKeyboardEvent |> Json.map handleKeydown)


handleKeydown : Keyboard.Event.KeyboardEvent -> ( Msg, Bool )
handleKeydown event =
    if event.key == Just "*" then
        ( StarPressed, True )

    else
        ( NoOp, False )


view model =
    div []
        [ div [ Events.onClick AddBulletClicked ]
            [ text "Add bullet" ]
        , div
            [ contenteditable True, onKeydown ]
            [ viewDocument model ]
        ]


type alias Model =
    Document


type Msg
    = AddBulletClicked
    | StarPressed
    | NoOp


update : Msg -> Model -> Model
update msg model =
    case msg of
        AddBulletClicked ->
            model |> addBullet

        StarPressed ->
            model |> addBullet

        NoOp ->
            model


main =
    Browser.sandbox
        { init = exampleDoc
        , view = view
        , update = update
        }
