import * as jhb from "./jhbshadow.js";

console.log("jhb loaded from test.js", jhb);

const div = document.getElementById("test-div");
const log = document.getElementById("log-div");
window.setInterval(() => {
    // const br = document.createElement("br");
    // log.prepend(br);

    // const content = document.createTextNode(computed);  
    // log.prepend(content || "null");
    const selection = document.getSelection();
    const selectionCache = {anchorNode: selection.anchorNode, anchorOffset: selection.anchorOffset, focusNode: selection.focusNode, focusOffset: selection.focusOffset};
    const computed = jhb.getSelectionRange(div);

    console.log("System selection", selectionCache);
    console.log("Current computed selection: ", computed);
    if (selectionCache.anchorNode !== computed.anchorNode) { console.log("ANCHOR NODES DIFFER (system, computed)", selectionCache.anchorNode, computed.anchorNode);}
    if (selectionCache.anchorOffset !== computed.anchorOffset) { console.log("ANCHOR OFFSETS DIFFER (system, computed)", selectionCache.anchorOffset, computed.anchorOffset);}
    if (selectionCache.focusNode !== computed.focusNode) { console.log("FOCUS NODES DIFFER (system, computed)", selectionCache.focusNode, computed.focusNode);}
    if (selectionCache.focusOffset !== computed.focusOffset) { console.log("FOCUS OFFSETS DIFFER (system, computed)", selectionCache.focusOffset, computed.focusOffset);}

}, 3000);