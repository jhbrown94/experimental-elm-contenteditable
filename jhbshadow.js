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
                // This child is fully contained.  It is the node.  

                // If it's text, we have to find the text location.
                if (typeof child.length !== 'undefined') {

                   return [child, null];
                }

                // Otherwise, the start point precedes it, so we can refer to the parent.
                return [node, index];
            }

            if (selection.containsNode(child, true)) {
                // This child is partially contained.
     
                // Is one of its kids the node?

                const result = getLeftNode(child);
                if (result) { return result; }
               
                // This child was partially contained, but none of its children were contained at all.
                // The caret is probably to the right, but there are special cases for the zeroth element.
                if (index == 0)  {
                    if (children.length == 1) {
                        // this is the only node.  The caret is to the left.
                        return [node, 0];                        
                    }
                    if (children.length > 1 && (!selection.containsNode(children[1], true))) {
                        // Neighbor to the right isn't partially selected.  Caret is to the left.
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
                // This child is fully contained.  It is the node.  

                // If it's text, we have to find the text location.
                if (typeof child.length !== 'undefined') {
                   return [child, null];
                }

                // Otherwise, the start point precedes it, so we can refer to the parent.
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
    let direction = "None";

    // Do we still need to compute the text offsets?
    if ((leftOffset === null) && (rightOffset === null)) {
        console.log("Double null");

        if (leftNode !== rightNode) {
            // Working across multiple nodes
            console.log("Different left and right nodes");

            const initialLength = selection.toString().length;

            // Try going left
            selection.extend(leftNode, 0);

            let [newRightNode, newRightOffset] = getRightNode(root);
            if (newRightNode == leftNode) {
                // Turns out the right node was focus.  Now selection is from start of text to left offset
                leftOffset = selection.toString().length;

                // Now, move selection back to rightNode
                selection.extend(rightNode, 0);
                rightOffset = initialLength - selection.toString().length;      
            } else {
                // Left node was focus.  So we just added a leftOffset's worth of text to the selection
                leftOffset = selection.toString().length - initialLength;

                // Now, shrink selection to just be rightOffset's worth of text
                selection.extend(rightNode, 0);
                rightOffset = selection.toString().length;
            }
        } else {
            // Selection is within one text node.
            console.log("Selection is in one text node.");
            let initialLength = selection.toString().length;

            // First special case: a caret (zero-length selection)
            if (initialLength === 0) {
                selection.extend(leftNode, 0);

                leftOffset = selection.toString().length;
                rightOffset = leftOffset;
            } else if (initialLength > 1) {
                let initialNext = leftNode.nextSibling;
                let initialData = leftNode.data;
                let dataLength = initialData.length;

                for (let dataLength = initialData.length; dataLength > 0; dataLength--) {
                    // With apologies to all MutationObservers, we find the selection by mutating things until the
                    // selection itself changes.  Basically, we split the last character off the node over and over.
                    leftNode.splitText(dataLength - 1);
                    console.log("Split selection", selection.toString());

                    // If the removed character was outside the selection, selection length doesn't change
                    if (selection.toString().length === initialLength) {
                        continue;
                    } 

                    // Aha, the selection got shorter.  Here are two things we know now.
                    rightOffset = dataLength;
                    leftOffset = rightOffset - initialLength;

                    // Because we said initialLength > 1, we know there's still one character in the selection. 
                    // So let's send Focus to leftOffset.  If it was already there, length doesn't change.
                    // If it wasn't already there, length goes to zero.
                    selection.extend(leftNode, leftOffset);
                    if (selection.toString().length === 0) {
                        direction = "RightIsFocus";
                    } else {
                        direction = "LeftIsFocus";
                    }
                    break;
                }

                // Clean up the mess we made splitting the node -- put back the data and get rid of the 
                // newly-created nodes.  
                leftNode.data = initialData;
                while (leftNode.nextSibling !== initialNext) {
                    leftNode.nextSibling.remove();
                }
            }
        }
    } else if (leftOffset === null) {
        console.log("Left null");

        // Right is solid.  It should be a non-text node, i.e. not this one.
        const initialLength = selection.toString().length;
        selection.extend(leftNode, 0);

        // Depending on selection direction, we may have moved our former "left" or "right" sides...
        let [newRightNode, newRightOffset] = getRightNode(root);
        if (newRightNode === leftNode) {
            // Looks like the right side was the focus.  We'll put it back in a minute.  But first, math.
            direction = "RightIsFocus";

            // We've selected from the offset point to the beginning of the text node.
            console.log("Right focus selction", selection.toString());
            rightOffset = selection.toString().length;
        } else {
            // The right side was the focus.  We just added an offset's worth of text.
            direction = "LeftIsFocus";
            rightOffset = selection.toString().length - initialLength;
        }

    } else if (rightOffset === null) {
        console.log("Right null");

        // Left is solid.  It should be a non-text node, i.e. not this one.
        const initialLength = selection.toString().length;
        selection.extend(rightNode, 0);

        // Depending on selection direction, we may have moved our former "left" or "right" sides...
        let [newLeftNode, newLeftOffset] = getLeftNode(root);
        if (newLeftNode === rightNode) {
            // Looks like the left side was the focus.  We'll put it back in a minute.  But first, math.
            direction = "LeftIsFocus";

            // We've selected from the offset point to the beginning of the text node.
            console.log("Left focus selction", selection.toString());
            rightOffset = selection.toString().length;
        } else {
            // The right side was the focus.  We just sliced out an offset's worth of text.
            direction = "RightIsFocus";
            rightOffset = initialLength - selection.toString().length;
        }
    }
    console.log("Direction", direction);

    let result;
    if (direction === "LeftIsFocus") {
        result = {
            anchorNode: rightNode,
            anchorOffset: rightOffset,
            focusNode: leftNode,
            focusOffset: leftOffset
        };
    } else {
        result = {
            anchorNode: leftNode,
            anchorOffset: leftOffset,
            focusNode: rightNode,
            focusOffset: rightOffset
        };
    }
    console.log("Result", result);
    selection.collapse(result.anchorNode, result.anchorOffset);
    selection.extend(result.focusNode, result.focusOffset);
    return result;
}

console.log("jhb loaded")