// Copyright 2020, Jeremy H. Brown

// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:

// 1. Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.

// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.

// 3. Neither the name of the copyright holder nor the names of its
// contributors may be used to endorse or promote products derived from this
// software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// What's this all for?

// Goal: let Elm have a state cycle with a contenteditable that looks a lot
// like a regular input -- state (HTML + selection) comes from an event on a
// custom view element, gets stored in the model, and used to generate the
// contents of the custom view element the next time `view` is called. Elm
// should also be able filter/modify the state before writing itŒ back into
// the slot in order to mutate the contenteditable.

// Implementation:  This file implements a custom element which contains a  div with
// contenteditable=true and a custom `state` property containing HTML and selection state
// from Elm.  When that property's contents chnage, they are propagated into
// the contenteditable and selection state.   In the other direction, when the user does
// input operations in the contenteditable, the contents of that
// contenteditable, along with the current selection, are emitted as an event.

function parseLiteHtml(node) {
  switch (node.type) {
    case "TextNode":
      return document.createTextNode(node.data.data);
    case "HtmlNode":
      const result = document.createElement(node.data.tag);
      for (const [name, value] of node.data.attributes) {
        result.setAttribute(name, value);
      }
      for (const child of node.data.children) {
        result.appendChild(parseLiteHtml(child));
      }
      return result;
    default:
      return document.createTextNode("UNABLE TO PARSE HTMLITE");
  }
}

function equalSelections(left, right) {
  if (left === right) {
    console.log("Identical objectx");
    return true;
  }

  if (!left || !right) {
    return false;
  }

  return (
    equalPaths(left.focus, right.focus) && equalPaths(left.anchor, right.anchor)
  );
}

function equalPaths(left, right) {
  if (left.length != right.length) {
    return false;
  }

  for (let i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }

  console.log("Elementwise equal", left, right);
  return true;
}

class CustomEditable extends HTMLElement {
  // Computes the path to a node as a series of integers, since we can't pass JS references into Elm.
  nodePath(offset, node) {
    const self = this;

    if (node) {
      let nodePath = [offset];

      let div = self._div;

      while (node != div && node.parentNode) {
        const index = Array.from(node.parentNode.childNodes).indexOf(node);
        nodePath.unshift(index);
        node = node.parentNode;
      }
      // If we never found the div, we weren't in the contenteditable to begin with
      if (!node.parentNode) {
        return null;
      }

      return nodePath;
    }
    return null;
  }

  constructor() {
    super();
    const self = this;

    document.addEventListener("selectionchange", (e) =>
      self.onSelectionChange(e)
    );

    Object.defineProperty(self, "state", {
      get() {
        return self._state;
      },

      set(state) {
        self._state = state;
        console.log("Set selection state from elm", state.selection);
        if (!self._div) {
          return;
        }
        const div = self._div;

        // Remove old div content
        while (div.childNodes.length > 0) {
          div.removeChild(div.childNodes[0]);
        }

        // Shovel in new content
        for (const node of state.html) {
          div.appendChild(parseLiteHtml(node));
        }

        const elmRange = state.selection;

        let range = null;

        if (elmRange) {
          const anchorPath = Array.from(elmRange.anchor);
          const focusPath = Array.from(elmRange.focus);
          let anchorNode = div;
          while (anchorPath.length > 1) {
            anchorNode = anchorNode.childNodes[anchorPath.shift()];
          }

          let focusNode = div;
          while (focusPath.length > 1) {
            focusNode = focusNode.childNodes[focusPath.shift()];
          }

          range = {
            anchorNode: anchorNode,
            anchorOffset: anchorPath.shift(),
            focusNode: focusNode,
            focusOffset: focusPath.shift(),
          };
        }
        const selection = window.getSelection();
        if (!range && !selection.anchorNode) {
          return;
        }
        if (range && selection.rangeCount > 0) {
          if (
            range.anchorNode === selection.anchorNode &&
            range.anchorOffset === selection.anchorOffset &&
            range.focusNode === selection.focusNode &&
            range.focusOffset === selection.focusOffset
          ) {
            return;
          }
        }
        selection.removeAllRanges();
        if (range) {
          selection.collapse(range.anchorNode, range.anchorOffset);
          selection.extend(range.focusNode, range.focusOffset);
        }
      },
    });
  }

  connectedCallback() {
    const self = this;
    const div = document.createElement("div");
    div.setAttribute("contenteditable", "");
    self.appendChild(div);
    self._div = div;
    div.addEventListener("input", (e) => self.onInput(e));

    // Trigger property update.  Ugly hack, TODO pull out the update into its own function and call it.
    console.log("Just once, set the state manually", self._state);
    self.state = self._state;
  }

  onSelectionChange(e) {
    const self = this;
    const currentSelection = self.getElmishSelection();
    if (equalSelections(currentSelection, self.state.selection)) {
      console.log("Early selection bail");
      return;
    }
    self.onInput(e);
  }

  getElmishSelection() {
    const self = this;
    const selection = document.getSelection();
    let elmRange = {
      focus: self.nodePath(selection.focusOffset, selection.focusNode),
      anchor: self.nodePath(selection.anchorOffset, selection.anchorNode),
    };

    if (!elmRange.focus || !elmRange.anchor) {
      elmRange = null;
    }
    return elmRange;
  }

  // User input happened.  Emit HTML and Selection in a custom event.
  onInput(e) {
    const self = this;

    if (!self._div) {
      return;
    }
    const div = self._div;

    const elmRange = self.getElmishSelection();

    const event = new CustomEvent("edited", {
      composed: true,
      bubbles: true,
      detail: { html: div.childNodes, selection: elmRange },
    });

    console.log(
      "Selection states old and emitted",
      self.state.selection,
      elmRange
    );
    div.dispatchEvent(event);
  }
}

// Define the new element
customElements.define("custom-editable", CustomEditable);
