//======================================================================
// Load MathJax, IFF the current browser can't handle MathML natively.

var LTX_mathjax_url = "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=MML_HTMLorMML";

function LTX_refreshMath(){
    // Maybe unnecessary, or overkill, but...
    if(typeof MathJax != "undefined"){
	MathJax.Hub.Queue(["Typeset",MathJax.Hub]);
    }}

var LTX_agent = navigator.userAgent;
// Add script element loading MathJax unless we can handle MathML
if (! ( ((LTX_agent.indexOf('Gecko') > -1)
         && (LTX_agent.indexOf('KHTML') === -1) && (LTX_agent.indexOf('Trident') === -1))
        || LTX_agent.match(/MathPlayer/) ) ){
    var script = document.createElement('script');
    var head = document.getElementsByTagName("head")[0];
    if(head != null){
        script.type = "text/javascript";
        script.src = LTX_mathjax_url;

        script.onreadystatechange = LTX_refreshMath;
        script.onload = LTX_refreshMath;

        head.appendChild(script); 
}}

    
