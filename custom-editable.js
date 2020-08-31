class CustomEditable extends HTMLElement {

  static get observedAttributes() { return ['dirty']; }

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

    var obs = new MutationObserver(function(mutations, observer) {
      const event = new CustomEvent('edited', { composed: true, bubbles: true, detail: div.childNodes });
      div.dispatchEvent(event);
    });
    obs.observe(div, {subtree: true, childList: true, attributes: true, characterData: true, attributeOldValue: true, characterDataOldValue: true});
  }

  connectedCallback() {
    this.attributeChangedCallback()
  }

  slotChangeCallback(e) {
    console.log("Slot changed", name);
    const self = this;
      let div = self.shadowRoot.querySelectorAll('div')[0];
      let slots = self.shadowRoot.querySelectorAll('slot');

      while (div.childNodes.length > 0 ) {
        div.removeChild(div.childNodes[0]);
      }

      for (const node of slots[0].assignedNodes()) {
        div.appendChild(node.cloneNode(true));
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