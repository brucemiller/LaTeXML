//======================================================================
// Load MathJax, IFF the current browser can't handle MathML natively.

var agent = navigator.userAgent;
var canMathML = ((agent.indexOf('Gecko') > -1) && (agent.indexOf('KHTML') === -1)
		 || agent.match(/MathPlayer/) );

// Add script element loading MathJax unless we can handle MathML
if (!canMathML) {
    var el = document.createElement('script');
    el.src = "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=MML_HTMLorMML";
    document.querySelector('head').appendChild(el); };
