# experimental-elm-contenteditable

This is a proof-of-concept for using contenteditable divs as custom elements
from Elm.  It's not production ready and has many glaring flaws.  Drop me a
line if you'd like to use it for something real and we can talk about how to
make it better.


How to run the demo (lightly tested on Chrome, Safari, and Firefox -- no mobile devices though)

1. Install the npm dependencies with `npm install`

2. Install parcel however you like.

3. run `parcel index.html`



How to use the code in your own project:

First, are you sure that's a good idea?  OK, go for it.


1. Install the npm dependencies with `npm install`

2. Your `index.html` file will need to include a couple of things directly or indirectly:
```
  <script src="custom-editable.js"></script>
```
and

```
  <template id="editable-template">
    <slot hidden="true">No slot content</slot>
    <div contenteditable="true" class="editable-template-container" style="width: 100%; height: 100%; outline: none;">Failed to prefill</div>
  </template>
```

The latter could be programmatically generated in `custom-editable.js` but it isn't yet.

3.  Start using this in Elm.  The minimalist Elm file will use these things:

```
import Editable
```

```
init : HtmlList -> State
```

`HtmlList` is a `List` of `Editable.Html` nodes, which are a ludicrously
simple data structure representing HTML nodes with attributes (no
properties/event handlers, though.)  `init` just assembles a valid initial
state that you can store in the model.  It's fine to pass `[]`.


This is what you use in your `view` function:

```
editable : List (Html.Attribute msg) -> (State -> msg) -> State -> Html.Html msg
```


That's probably enough threads to pull on to dive into the code.  I'm happy to
chat if you have questions.  I'd love to polish this more for users, but 
I've gotten out of the experiment what I wanted to for myself :)