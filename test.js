import * as jhb from "./jhbshadow.js";

console.log("jhb loaded from test.js", jhb);

const div = document.getElementById("test-div");
const log = document.getElementById("log-div");

document.addEventListener('-jhb-selectionchange', (e) => {
    const selection = document.getSelection();
    const selectionCache = {anchorNode: selection.anchorNode, anchorOffset: selection.anchorOffset, focusNode: selection.focusNode, focusOffset: selection.focusOffset};
    const text = selection.toString();
    const computed = jhb.getSelectionRange(div);

    console.log("System selection", selectionCache);
    console.log("Current computed selection: ", computed);
    console.log("text", text);

    if (computed) {
        if (selectionCache.anchorNode !== computed.anchorNode) { console.log("ANCHOR NODES DIFFER (system, computed)", selectionCache.anchorNode, computed.anchorNode);}
        if (selectionCache.anchorOffset !== computed.anchorOffset) { console.log("ANCHOR OFFSETS DIFFER (system, computed)", selectionCache.anchorOffset, computed.anchorOffset);}
        if (selectionCache.focusNode !== computed.focusNode) { console.log("FOCUS NODES DIFFER (system, computed)", selectionCache.focusNode, computed.focusNode);}
        if (selectionCache.focusOffset !== computed.focusOffset) { console.log("FOCUS OFFSETS DIFFER (system, computed)", selectionCache.focusOffset, computed.focusOffset);}
    }
});


window.setInterval(() => {console.log(jhb.getSelectionRange(div));}, 2000);
