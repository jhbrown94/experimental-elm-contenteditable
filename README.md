# experimental-elm-contenteditable

This is a proof-of-concept for using contenteditable divs as custom elements
from Elm. It's not production ready and has many glaring flaws. Drop me a
line if you'd like to use it for something real and we can talk about how to
make it better.

This has been lightly tested on Chrome, Safari, and Firefox -- no mobile devices though.

## How to run the demo

1. Install parcel (with, e.g., `npm install -g parcel`)

2. run `parcel index.html`

## How to use the code in your own project

First, are you sure that's a good idea? OK, go for it.

1. Your `index.html` file should include (directly or indirectly):

```
  <script src="custom-editable.js"></script>
```

2.  Start using this in Elm. The minimalist Elm file will use these things:

```
import Editable
```

```
init : HtmlList -> State
```

`HtmlList` is a `List` of `HtmlLite.Html` nodes, which are a ludicrously
simple data structure representing HTML nodes with attributes (no
properties/event handlers, though.) `init` just assembles a valid initial
state that you can store in the model. It's fine to pass `[]`.

This is what you use in your `view` function:

```
editable : List (Html.Attribute msg) -> (State -> msg) -> State -> Html.Html msg
```

That's probably enough threads to pull on to dive into the code. I'm happy to
chat if you have questions. I'd love to polish this more for users, but
I've gotten out of the experiment what I wanted to for myself :)
