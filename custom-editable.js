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

// Implementation:  This file implements a custom element.  That contains a
// shadowRoot, which in turn contains a hidden slot and a visible div with
// contenteditable=true. When the slot's contents chnage, they are cloned into
// the visible contenteditable.   In the other direction, when the user does
// input operations in the contenteditable, the contents of that
// contenteditable, along with the current selection, are emitted as an event.

const jhb = require ('@jhbrown94/selectionrange');


class CustomEditable extends HTMLElement {

  // Computes the path to a node as a series of integers, since we can't pass JS references into Elm.
  nodePath(offset, node) {
      if (node) {
        let nodePath = [offset];

        let div = this.shadowRoot.querySelectorAll('div')[0];

        while (node != div && node.parentNode ) {
            const index = Array.from(node.parentNode.childNodes).indexOf(node);
            nodePath.unshift(index);
            node = node.parentNode;
        }

        return nodePath;
      }
      return null;
  }

  constructor() {
    super();
    const self = this;
    var shadowRoot = self.attachShadow({mode: 'open'});
    let template = document.getElementById('editable-template');
    let templateContent = template.content;
    shadowRoot.appendChild(templateContent.cloneNode(true));

    let div = shadowRoot.querySelectorAll('div')[0];
    let slot = shadowRoot.querySelectorAll('slot')[0];

    // Watch for top-level slot nodes getting moved around
    slot.addEventListener('slotchange', () => self.onSlotChanged());

    div.addEventListener('input', (e) => self.onInput(e));

    self.slotObserver = new MutationObserver((e) => self.onSlotChanged(e));

    document.addEventListener('selectionchange', (e) => self.onInput(e));
  }

  // User input happened.  Emit HTML and Selection in a custom event.
  onInput(e) {      
      const self = this;
      const range = jhb.getSelectionRange(self.shadowRoot);
      let elmRange = null;

      if (range) {
        elmRange = {focus: self.nodePath(range.focusOffset, range.focusNode), 
          anchor: self.nodePath(range.anchorOffset, range.anchorNode)};
      }

      let div = self.shadowRoot.querySelectorAll('div')[0];

      const event = new CustomEvent('edited', { composed: true, bubbles: true, detail: {html: div.childNodes, selection: elmRange}});
      div.dispatchEvent(event);      
  }

  // Something changed the slot contents.  Copy it into the visible body.
  onSlotChanged(e) {
    const self = this;

    let slot = self.shadowRoot.querySelectorAll('slot')[0];
    let div = self.shadowRoot.querySelectorAll('div')[0];

      while (div.childNodes.length > 0 ) {

        div.removeChild(div.childNodes[0]);
      }

      // TODO: lots of ways to make this more efficient.
        self.slotObserver.disconnect();
      for (const node of slot.assignedNodes()) {
        div.appendChild(node.cloneNode(true));

        // Monitor the new children for any mutations.
        self.slotObserver.observe(node, {subtree: true, childList: true, attributes: true, characterData: true, attributeOldValue: true, characterDataOldValue: true});
      }

    const elmRange = JSON.parse(self.getAttribute("selection"));


    let range = null;

    if (elmRange) {
      const anchorPath = elmRange.anchor;
      const focusPath = elmRange.focus;
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
        focusOffset: focusPath.shift()
      }
    }
    jhb.setSelectionRange(self.shadowRoot, range);
  }

}

// Define the new element
customElements.define('custom-editable', CustomEditable);