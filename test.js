import * as jhb from "./jhbshadow.js";

console.log("jhb loaded from test.js", jhb);

const div = document.getElementById("test-div");
const log = document.getElementById("log-div");
window.setInterval(() => {
    // const br = document.createElement("br");
    // log.prepend(br);

    // const content = document.createTextNode(range);  
    // log.prepend(content || "null");
    const sysrange = document.getSelection().getRangeAt(0);
    console.log("Current system range:", sysrange);

    const range = jhb.getSelectionRange(div);
    console.log("Current computed range: ", range);

    if (sysrange.startContainer !== range.startContainer) { console.log("START NODES DIFFER (system, computed)", sysrange.startContainer, range.startContainer);}
    if (sysrange.startOffset !== range.startOffset) { console.log("START OFFSETS DIFFER (system, computed)", sysrange.startOffset, range.startOffset);}
    if (sysrange.endContainer !== range.endContainer) { console.log("END NODES DIFFER (system, computed)", sysrange.endContainer, range.endContainer);}
    if (sysrange.endOffset !== range.endOffset) { console.log("END OFFSETS DIFFER (system, computed)", sysrange.endOffset, range.endOffset);}

}, 1000);