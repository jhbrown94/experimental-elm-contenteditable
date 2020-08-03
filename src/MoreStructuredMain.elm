module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes as Attributes exposing (contenteditable, style)
import Html.Events as Events
import Json.Decode as Json
import Keyboard.Event


type alias DocumentList =
    List Document


type Document
    = Text String
    | Paragraph DocumentList
    | Sequence DocumentList
    | Bullets DocumentList


exampleDoc =
    Sequence
        [ Paragraph [ Text "Begin here" ]
        , Bullets
            [ Text "first item"
            , Sequence
                [ Text "next item"
                , Bullets [ Text "Nested item" ]
                ]
            ]
        , Text "End here"
        , Text ". Finale."
        ]


addBullet : Document -> Document
addBullet document =
    let
        recurse list =
            List.map addBullet list
    in
    case document of
        Bullets list ->
            Bullets <| List.append (recurse list) [ Text "Bullet added." ]

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
            List.map viewDocument list
    in
    case document of
        Text s ->
            text s

        Sequence list ->
            div [] (recurse list)

        Paragraph list ->
            p [] (recurse list)

        Bullets list ->
            ul [] (recurse list |> List.map (\x -> li [] [ x ]))


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
