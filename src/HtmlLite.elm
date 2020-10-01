module HtmlLite exposing (..)

import Json.Encode as Encode
import List.Extra


type Html
    = TextNode String
    | HtmlNode String Attributes (List Html)


type alias Attributes =
    List Attribute


type alias Attribute =
    ( String, String )


getAttribute : String -> Attributes -> Maybe String
getAttribute name attrs =
    List.Extra.find (\( k, v ) -> k == name) attrs |> Maybe.map Tuple.second


i =
    HtmlNode "i"


b =
    HtmlNode "b"


p =
    HtmlNode "p"


text =
    TextNode


img =
    HtmlNode "img"


a =
    HtmlNode "a"


encodeHtml html =
    let
        ( dataType, data ) =
            case html of
                TextNode value ->
                    ( "TextNode", Encode.object [ ( "data", Encode.string value ) ] )

                HtmlNode tag attrs children ->
                    ( "HtmlNode"
                    , Encode.object
                        [ ( "tag", Encode.string tag )
                        , ( "attributes", Encode.list encodeAttribute attrs )
                        , ( "children", Encode.list encodeHtml children )
                        ]
                    )
    in
    Encode.object [ ( "type", Encode.string dataType ), ( "data", data ) ]


encodeAttribute ( name, value ) =
    Encode.list Encode.string [ name, value ]
