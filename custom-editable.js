//const shadow = require('shadow-selection-polyfill');

const jhb = require ('@jhbrown94/selectionrange');

class CustomEditable extends HTMLElement {

  static get observedAttributes() { return ['dirty']}

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
    slot.addEventListener('slotchange', () => {console.log("Top-level slot change event"); self.onSlotChanged()});

    function onInput() {      
      const range = jhb.getSelectionRange(shadowRoot);
      console.log("onInput handler");
      //console.log("Edited callback slot", slot.assignedNodes());
      console.log("Edited callback div", div.childNodes);

      let elmRange = null;

      if (range) {
        elmRange = {focus: self.nodePath(range.focusOffset, range.focusNode), 
          anchor: self.nodePath(range.anchorOffset, range.anchorNode)};
      }

      const event = new CustomEvent('edited', { composed: true, bubbles: true, detail: {html: div.childNodes, selection: elmRange}});
      div.dispatchEvent(event);      
    }

    div.addEventListener('input', () => onInput());

    self.slotObserver = new MutationObserver(() => {console.log("Slot subnode mutation event"); self.onSlotChanged()});

    document.addEventListener('selectionchange', () => {console.log("Selection event"); onInput();});
  }

  connectedCallback() {
    this.attributeChangedCallback()
  }

  onSlotChanged(e) {
    const self = this;
    console.log("onSlotChanged handler");

    let slot = self.shadowRoot.querySelectorAll('slot')[0];
    let div = self.shadowRoot.querySelectorAll('div')[0];

    console.log("Slot change callback slot[0]", slot.assignedNodes()[0]);
    console.log("Slot change callback div[0]", div.childNodes[0]);

      while (div.childNodes.length > 0 ) {

        div.removeChild(div.childNodes[0]);
      }

      // TODO: lots of ways to make this more efficient.
        self.slotObserver.disconnect();
      for (const node of slot.assignedNodes()) {
        console.log("appending new", node)
        div.appendChild(node.cloneNode(true));

        // Monitor the new children for any mutations.
        self.slotObserver.observe(node, {subtree: true, childList: true, attributes: true, characterData: true, attributeOldValue: true, characterDataOldValue: true});
      }


    console.log("Slot change callback final div[0]", div.childNodes[0]);

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
  

  attributeChangedCallback(name, oldValue, newValue) {
      console.log("name, oldValue, newValue", [name, oldValue, newValue]);

    let slot = this.shadowRoot.querySelectorAll('slot')[0];
    let div = this.shadowRoot.querySelectorAll('div')[0];

    console.log("attr change callback slot[0]", slot.assignedNodes()[0]);
    console.log("attr change callback div[0]", div.childNodes[0]);

    if (name === "dirty" && newValue === "true") {
     this.slotChangeCallback();
   }
 }

}

// Define the new element
customElements.define('custom-editable', CustomEditable);