/**
 * Copyright 2020 Jeremy H. Brown
 * 
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License. You may obtain a copy of
 * the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations under
 * the License.
 */


// This is an attempt at determining the complete selection, down to the
// individual HTML node, down to the individual characters, with
// directionality, inside a shadowRoot on Safari. It is heavily informed by
// https://github.com/GoogleChromeLabs/shadow-selection-polyfill which is
// short on comments but long on useful techniques.  Since I have the memory
// of a sieve, I will attempt to include more comments in here.

// To begin with, why are we here?  

// In Safari, there is no getSelection method on shadowRoot.  If the selection
// is inside a shadowRoot, and you get a Selection from document.getSelection,
// selection.getRangeAt(0) returns a range which is a single point right
// before the shadow dom.  This is enforced at the C++ level.  So we need to
// derive an actual selection range ourselves. 

// The good news is that most other Seletion methods still work.  In
// particular, to figure out which nodes you are in, Selection.containsNode
// still works -- you get real answers if you pass it nodes from inside the
// shadow DOM.  So you can interrogate  it piecemeal to determine the start
// and end nodes of the real selection range.

// Similarly, Selection.collapse, Selection.extend, and Selection.toString all
// work with nodes from the Shadow DOM.  So by playing various games with text
// nodes, you can ultimately derive the offsets within text nodes as well.


// Taken almost literally from
// https://github.com/GoogleChromeLabs/shadow-selection-polyfill
const hasShadowSelection = !!(document.createElement('div').attachShadow({ mode: 'open' }).getSelection);
const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent) ||
  /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;

// Don't propagate selectionchanged events when true -- we're just letting the ones we generated
// settle out.  There's a risk of missing user-generated selectionevents, though, due
// to our inability to precisely bracket selectionchange events we generate -- trying
// to use setTimeout to bracket isn't guaranteed because Safari seems to handle that
// on a separate task queue from the selectionchange events, which all go first.
let squelchEvent = false;

export function isSquelchingEvents() {
    return squelchEvent;
}

export const eventName = '-jhb-selectionchange';

function selectionChangeHandler(e) {
    // Early exit if we've recently notified about this, or have recently
    // gotten the range with getSelectionRange
    if (squelchEvent) {
        return;
    }

    // Dispatch our custom event synchronously
    document.dispatchEvent(new CustomEvent(eventName));

    if (isSafari) {
        squelchEvent = true;

        // Safari seems to run all selection event handlers before user-queued
        // tasks.  So this will run after queued selectionchange events.  However,
        // it's hacky -- it's at least theoretically possible that some other
        // event handler could modify the selection (including by modifying the
        // DOM) before we get around to this.
        window.setTimeout(() => {
            squelchEvent = false; 
        }, 0);
    }
};

document.addEventListener('selectionchange', selectionChangeHandler);

export function getSelectionRange(root) {

    // Only Chrome AFAIK
    if (hasShadowSelection) {
        const s = root.getSelection();
        if (!root.anchorNode) { return null;}
         return  {
            anchorNode: s.anchorNode,
            anchorOffset: s.anchorOffset,
            focusNode: s.focusNode,
            focusOffset: s.focusOffset
        };
    }

    // Firefox
    if (!isSafari) {
        const s = document.getSelection();
        if (!root.anchorNode) { return null;}

        if (!s.containsNode(root, true)) {
            return null;
        }

        return  {
            anchorNode: s.anchorNode,
            anchorOffset: s.anchorOffset,
            focusNode: s.focusNode,
            focusOffset: s.focusOffset
        };
    }

    // Safari.  Here we go!
    const selection = document.getSelection();
    console.log("Real selection:", selection);

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
               
                // This child was partially contained, but none of its
                // children were contained at all. The caret is probably to
                // the right, but there are special cases for the zeroth
                // element.
                if (index == 0)  {
                    if (children.length == 1) {
                        // this is the only node.  The caret is to the left.
                        // NOTE: there is probably a special case that can be created with splitText -- we'll flail on that here.
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

    let leftResult = getLeftNode(root);
    let rightResult = getRightNode(root);

    if (!leftResult || !rightResult) {
        return null;
    }

    let [leftNode, leftOffset] = leftResult;
    let [rightNode, rightOffset] = rightResult;
    let direction = null;
        
    if ((leftOffset === null) && (rightOffset === null)) {

        if (leftNode !== rightNode) {
            // Working across multiple nodes

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

                direction = "RightIsFocus"; 
            } else {
                // Left node was focus.  So we just added a leftOffset's worth of text to the selection
                leftOffset = selection.toString().length - initialLength;


                // Now, shrink selection to just be rightOffset's worth of text
                selection.extend(rightNode, 0);
                rightOffset = selection.toString().length;

                direction = "LeftIsFocus";
            }
        } else {
            // Selection is within one text node.
            let initialLength = selection.toString().length;

            // First special case: a caret (zero-length selection)
            if (initialLength === 0) {
                selection.extend(leftNode, 0);

                leftOffset = selection.toString().length;

                rightOffset = leftOffset;
                direction = "None";
            } else {
                let initialNext = leftNode.nextSibling;
                let initialData = leftNode.data;
                let dataLength = initialData.length;

                for (let dataLength = initialData.length; dataLength > 0; dataLength--) {
                    // With apologies to all MutationObservers, we find the selection by mutating things until the
                    // selection itself changes.  Basically, we split the last character off the node over and over.
                    leftNode.splitText(dataLength - 1);

                    // For what it's worth, Safari doesn't generate a selectionchange event on a text node split, even though it changes
                    // the selection. 

                    // If the removed character was outside the selection, selection length doesn't change
                    if (selection.toString().length === initialLength) {
                        continue;
                    } 

                    // Aha, the selection got shorter.  Here are two things we know now.
                    rightOffset = dataLength;
                    leftOffset = rightOffset - initialLength;

                    // Let's add one character back.  In Safari, the selection's anchor or focus will expand
                    // to include that.
                    leftNode.appendData("*");
                    // I believe this DOES generate a selectionchange event

                    // Now we know there's at least one character in the selection. 
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

                // I believe this DOES generate a selectionchange event
                leftNode.data = initialData;
                while (leftNode.nextSibling !== initialNext) {
                    leftNode.nextSibling.remove();
                }
            }
        }
    } else if (leftOffset === null) {
        

        // Right is solid.  It should be a non-text node, i.e. not this one.
        const initialLength = selection.toString().length;
        selection.extend(leftNode, 0);

        // Depending on selection direction, we may have moved our former "left" or "right" sides...
        let [newRightNode, newRightOffset] = getRightNode(root);
        if (newRightNode === leftNode) {
            
            // Looks like the right side was the focus.  We'll put it back in a minute.  But first, math.
            direction = "RightIsFocus";

            // We've selected from the offset point to the beginning of the text node.
            
            leftOffset = selection.toString().length;
        } else {
            // The right side was the focus.  We just added an offset's worth of text.
            direction = "LeftIsFocus";
            leftOffset = selection.toString().length - initialLength;
        }

    } else if (rightOffset === null) {
        

        // Left is solid.  It should be a non-text node, i.e. not this one.
        const initialLength = selection.toString().length;
        selection.extend(rightNode, 0);

        // Depending on selection direction, we may have moved our former "left" or "right" sides...
        let [newLeftNode, newLeftOffset] = getLeftNode(root);
        if (newLeftNode === rightNode) {
            // Looks like the left side was the focus.  We'll put it back in a minute.  But first, math.
            direction = "LeftIsFocus";

            // We've selected from the offset point to the beginning of the text node.
            
            rightOffset = selection.toString().length;
        } else {
            // The right side was the focus.  We just sliced out an offset's worth of text.
            direction = "RightIsFocus";
            const selLength = selection.toString().length;
            rightOffset = initialLength - selLength;
        }
    } else {
        // we just need direction
        if (leftNode !== rightNode || leftOffset !== rightOffset) {
            selection.extend(rightNode, rightOffset);
            let [newLeftNode, newLeftOffset] = getLeftNode(root);

            if (newLeftNode === leftNode && newLeftOffset === leftOffset) {
                // if left didn't move, then it was the anchor
                direction = "RightIsFocus";
            } else {
                direction = "LeftIsFocus";
            }
        } else {
            // caret
            direction = "None";
        }
    }
    

    let result;
    if (!direction) {
        console.log("FAIL: direction is null");
    }

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
    
    selection.collapse(result.anchorNode, result.anchorOffset);
    selection.extend(result.focusNode, result.focusOffset);
    return result;
}

export function setSelectionRange(root, range) {
    let selection;
    if (hasShadowSelection) {
        selection = root.getSelection();
    } else {
        selection = document.getSelection();
    }
    if (!range) {
        selection.removeAllRanges();
        return;
    }
    selection.collapse(range.anchorNode, range.anchorOffset);
    selection.extend(range.focusNode, range.focusOffset);
}
