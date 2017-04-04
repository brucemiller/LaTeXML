//======================================================================
// Load MathJax, IFF the current browser can't handle MathML natively.

(function() {
    var mathjax_url =
        "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.0/MathJax.js?config=MML_HTMLorMML";

    function refreshMath() {
        // Maybe unnecessary, or overkill, but...
        if (typeof MathJax != "undefined") {
            MathJax.Hub.Queue(["Typeset", MathJax.Hub]);
        }
    }

    // Add script element loading MathJax unless we can handle MathML
    var agent = navigator.userAgent;
    var is_gecko = (agent.indexOf("Gecko") > -1 &&
                    agent.indexOf("KHTML") === -1 &&
                    agent.indexOf("Trident") === -1);
    // Check for MathPlayer, but only IE's before IE 10 when it was disabled.
    var has_mathplayer = (agent.indexOf("MathPlayer") > -1 &&
                    agent.indexOf("rv:1") === -1); /* till ie 20! */
    if (!is_gecko && !has_mathplayer) {
        var head = document.getElementsByTagName("head")[0];
        if (head != null) {
            var script = document.createElement("script");
            script.type = "text/javascript";
            script.src = mathjax_url;
            script.onreadystatechange = refreshMath;
            script.onload = refreshMath;
            head.appendChild(script);
        }
    }
}());
