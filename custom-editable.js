//const shadow = require('shadow-selection-polyfill');

import * as jhb from "./jhbshadow.js";

class CustomEditable extends HTMLElement {

  static get observedAttributes() { return ['dirty']; }

  nodePath(offset, node) {
      if (node) {
        let nodePath = [offset];

        while (node != this.shadowRoot && node.parentNode ) {
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

    let slots = shadowRoot.querySelectorAll('slot');
    slots[0].addEventListener('slotchange', function (e) {self.slotChangeCallback(e);});
    let div = shadowRoot.querySelectorAll('div')[0];

    function emitEdited() {
      if (jhb.isSquelchingEvents()) {console.log("Squelch."); return;}
      console.log("Mutated.");
      const range = jhb.getSelectionRange(shadowRoot);
      console.log("getSelectionRange called from customEditable:", range);
      let elmRange = null;


      if (range) {
        elmRange = {end: self.nodePath(range.focusOffset, range.focusNode), 
          start: self.nodePath(range.anchorOffset, range.anchorNode)};
      }

      const event = new CustomEvent('edited', { composed: true, bubbles: true, detail: {html: div.childNodes, selection: elmRange}});
      div.dispatchEvent(event);      
    }

    var obs = new MutationObserver(function(mutations, observer) { emitEdited();});
    obs.observe(div, {subtree: true, childList: true, attributes: true, characterData: true, attributeOldValue: true, characterDataOldValue: true});

    document.addEventListener(jhb.eventName, function () {emitEdited();});
  }

  connectedCallback() {
    this.attributeChangedCallback()
  }

  slotChangeCallback(e) {
    const self = this;
      let div = self.shadowRoot.querySelectorAll('div')[0];
      let slots = self.shadowRoot.querySelectorAll('slot');

      while (div.childNodes.length > 0 ) {
        div.removeChild(div.childNodes[0]);
      }

      for (const node of slots[0].assignedNodes()) {
        div.appendChild(node.cloneNode(true));
      }

    const elmRange = JSON.parse(self.getAttribute("selection"));


    let range = null;

    if (elmRange) {
      const startPath = elmRange.start;
      const endPath = elmRange.end;
      let startNode = self.shadowRoot;
      while (startPath.length > 1) {
        startNode = startNode.childNodes[startPath.shift()];
      }
      
      let endNode = self.shadowRoot;
      while (endPath.length > 1) {
        endNode = endNode.childNodes[endPath.shift()];
      }

      range = {
        anchorNode: startNode,
        anchorOffset: startPath.shift(),
        focusNode: endNode,
        focusOffset: endPath.shift()
      }
    }
    console.log("SetSelectionRange", range);
    jhb.setSelectionRange(self.shadowRoot, range);
  }
  

  attributeChangedCallback(name, oldValue, newValue) {
    if (name == "dirty") {
     this.slotChangeCallback();
   }
 }

}

// Define the new element
customElements.define('custom-editable', CustomEditable);