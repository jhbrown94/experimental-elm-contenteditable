class CustomEditable extends HTMLElement {
  // I'm not clear why Elm does the attributes late, but it does, so if we don't
  // monitor them as they change we can render data from some other custom call.  It's weird.
  static get observedAttributes() { return ['data-text']; }

  constructor() {
    super();
    var shadow = this.attachShadow({mode: 'open'});
    // const style = document.createElement('style');

    //     style.textContent = `
    // a {
    //   color: #127FBF;
    // }

    // * {
    //   white-space: normal !important;
    //   line-height: 1.5;
    // }
    //       `;

    //         shadow.appendChild(style);

    const ce = document.createElement('div');
    ce.setAttribute('contenteditable', 'true');
    shadow.appendChild(ce);
  }

  connectedCallback() {
    this.attributeChangedCallback()
  }

  attributeChangedCallback(name, oldValue, newValue) {
    const shadow = this.shadowRoot;
    const ce = shadow.querySelector('div');
    var text = this.getAttribute('data-text');

    ce.innerHTML = text;
  }
}

// Define the new element
customElements.define('custom-editable', CustomEditable);