class CustomEditable extends HTMLElement {

  static get observedAttributes() { return ['dirty']; }

  nodePath(offset, node) {
      if (node) {
        let focusPath = [offset];

        while (node != this.shadowRoot && node.parentNode ) {
            const index = Array.from(node.parentNode.childNodes).indexOf(node);
            focusPath.unshift(index);
            node = node.parentNode;
        }

        return focusPath;
      }
      return null;
  }

  constructor() {
    super();
    const self = this;
    var shadow = self.attachShadow({mode: 'open'});
    let template = document.getElementById('editable-template');
    let templateContent = template.content;
    shadow.appendChild(templateContent.cloneNode(true));

    let slots = self.shadowRoot.querySelectorAll('slot');
    slots[0].addEventListener('slotchange', function (e) {self.slotChangeCallback(e);});
    let div = self.shadowRoot.querySelectorAll('div')[0];

    function emitEdited() {
      const selection = shadow.getSelection();
      let elmSelection = {type: selection.type};

      if (selection.type != "None") {
        elmSelection.focus = self.nodePath(selection.focusOffset, selection.focusNode);
        elmSelection.anchor = self.nodePath(selection.anchorOffset, selection.anchorNode);
      }

      const event = new CustomEvent('edited', { composed: true, bubbles: true, detail: {html: div.childNodes, selection: elmSelection}});
      div.dispatchEvent(event);      
    }

    var obs = new MutationObserver(function(mutations, observer) { emitEdited();});
    obs.observe(div, {subtree: true, childList: true, attributes: true, characterData: true, attributeOldValue: true, characterDataOldValue: true});

    document.addEventListener('selectionchange', function () {emitEdited();});
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


    const elmSelection = JSON.parse(self.getAttribute("selection"));

    if (!elmSelection) {return;}

    let selection = document.getSelection();
    selection.removeAllRanges();
    if (elmSelection.type !== "None") {
      const focusPath = elmSelection.focus;
      const anchorPath = elmSelection.anchor;
      let range = document.createRange();

      let focusNode = self.shadowRoot;
      while (focusPath.length > 1) {
        focusNode = focusNode.childNodes[focusPath.shift()];
      }
      range.setStart(focusNode, focusPath.shift());

      let anchorNode = self.shadowRoot;
      while (anchorPath.length > 1) {
        anchorNode = anchorNode.childNodes[anchorPath.shift()];
      }
      range.setEnd(anchorNode, anchorPath.shift());

      selection.addRange(range);
    }
  }
  

  attributeChangedCallback(name, oldValue, newValue) {
    if (name == "dirty") {
     this.slotChangeCallback();
   }
 }

}

// Define the new element
customElements.define('custom-editable', CustomEditable);