// This is an attempt at determining the complete selection, down to the individual HTML node, inside a shadowRoot on Safari.
// It is heavily informed by staring at https://github.com/GoogleChromeLabs/shadow-selection-polyfill
// which is short on comments but long on useful techniques.  Since I have the memory of a sieve,
// I will attempt to include more comments in here.

// To begin with, why are we here?  

// In Safari, there is no getSelection method on shadowRoot.  If the selection is inside
// a shadowRoot, and you get a Selection from document.getSelection, selection.getRangeAt(0) returns a range which is a single point right
// before the shadow dom.  This is enforced at the C++ level.  So we need to derive an actual selection range ourselves. 

// The good news is that Selection.containsNode still works -- you get real answers if you pass it nodes from inside the shadow DOM.  So you can interrogate 
// it piecemeal to determine the start and end nodes of the real selection range.

// TODO: text / etc.



export function getSelectionRange(root) {
    const selection = document.getSelection();
    if (!selection.containsNode(root, true)) {
        return null;
    }


    function getLeftNode(node) {
        let children = Array.from(node.childNodes);

        for (let [index, child] of children.entries()) {

            if (selection.containsNode(child, false)) {
                // This child is fully contained.  It is the node.  Which means the
                // start point precedes it, so we can refer to the parent.

                // TODO: text offsets are different.
                return [node, index];
            }

            if (selection.containsNode(child, true)) {
                // This chld is partially contained.
     
                // Is one of its kids the node?
                const result = getLeftNode(child);
                if (result) { return result; }
               
                // This child was partially contained, but none of its children were contained at all.
                // The caret is probably to the right, but there's one special case.

                // If this is the zeroth element, and there's an element to the right, but that element
                // isn't partially contained, then the caret is to the left of this element at parent offset 0.
                if (index == 0 && children.length > 1) {
                    if (!selection.containsNode(children[1], true)) {
                        return [node, 0]
                    }
                }
                // In all other cases, the caret is to the right.
                return [node, index + 1];
            }
        }

        // This node's children are not even a little bit contained.
        return null;
    }    



    function getRightNode(node) {
        let children = Array.from(node.childNodes);

        for (let index = children.length - 1; index >= 0; index--) {
            let child = children[index];

            if (selection.containsNode(child, false)) {
                // This child is fully contained.  It is the node.  Which means the
                // start point precedes it, so we can refer to the parent.

                // TODO: text offsets are different.
                return [node, index];
            }

            if (selection.containsNode(child, true)) {
                // This chld is partially contained.
     
                // Is one of its kids the node?
                const result = getRightNode(child);
                if (result) { return result; }
               
               // This child was partially contained, but none of its children were contained at all.
                // The caret is always to the left.
                return [node, index];
            }
        }

        // This node's children are not even a little bit contained.
        return null;
    }    

    let [leftNode, leftOffset] = getLeftNode(root);
    let [rightNode, rightOffset] = getRightNode(root);

    let range = document.createRange();
    range.setStart(leftNode, leftOffset);
    range.setEnd(rightNode, rightOffset);

    return range;
}

console.log("jhb loaded")