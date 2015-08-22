//======================================================================
// Load MathJax, IFF the current browser can't handle MathML natively.

(function() {
    var mathjax_url =
        "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=MML_HTMLorMML";

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
    var has_mathplayer = agent.match(/MathPlayer/);
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
