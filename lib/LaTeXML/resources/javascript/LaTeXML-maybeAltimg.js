//======================================================================
// Display altimg, IFF the current browser can't handle MathML natively.

(function() {
    function refreshMath() {
        var mathml_namespace = "http://www.w3.org/1998/Math/MathML";
        if (document.body != null) {
            // Replace each <math> tag with an <img> tag. Note that each such
            // replacement automatically decreases the length of the maths list
            // so we always work on the 0-th item.
            var maths =
                document.getElementsByTagNameNS(mathml_namespace, "math");
            while (maths.length > 0) {
                var math = maths[0];
                var img = document.createElement("img");
                img.src = math.getAttribute("altimg") || "";
                img.alt = math.getAttribute("alttext") || "";

                // MathML attributes and CSS properties have slightly different
                // syntaxes, but this should work for most length values with
                // explicit unit.
                if (math.hasAttribute("altimg-width")) {
                    img.style.width = math.getAttribute("altimg-width");
                }
                if (math.hasAttribute("altimg-height")) {
                    img.style.height = math.getAttribute("altimg-height");
                }
                if (math.hasAttribute("altimg-valign")) {
                    img.style.verticalAlign = math.getAttribute("altimg-valign");
                }

                math.parentNode.replaceChild(img, math);
            }
        }
    }

    // Use alt images unless we can handle MathML
    var agent = navigator.userAgent;
    var is_gecko = (agent.indexOf("Gecko") > -1 &&
                    agent.indexOf("KHTML") === -1 &&
                    agent.indexOf("Trident") === -1);
    var has_mathplayer = agent.match(/MathPlayer/);
    if (!is_gecko && !has_mathplayer) {
        refreshMath();
        // Maybe unnecessary, or overkill, but...
        window.addEventListener("DOMContentReady", refreshMath);
        window.addEventListener("load", refreshMath);
    }
}());
