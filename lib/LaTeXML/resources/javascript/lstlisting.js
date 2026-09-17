// replace download links in lstlisting environments by copy to clipboard button
// requires images/copy.svg and images/ok.svg
// (c) Christoph Hauert 2025

function copy2clip(button) {
	try {
		// temporarily hide line numbers in code listing
	    const style = document.createElement('style');
	    document.head.appendChild(style);
	    const styleSheet = style.sheet;
		var hideLine = styleSheet.insertRule(".ltx_tag_listingline { display: none; }");
		var hideCopy = styleSheet.insertRule(".ltx_listing_data { display: none; }");
	    const textToCopy = button.parentNode.parentNode.parentNode.innerText;
		navigator.clipboard.writeText(textToCopy);
		styleSheet.deleteRule(hideCopy);
		styleSheet.deleteRule(hideLine);
		button.classList.remove("error");
		button.classList.add("success");
	} catch (e) {
		button.classList.remove("success");
		button.classList.add("error");
	}
	setTimeout(() => {
		button.classList.remove("success", "error");
	}, 1200);
}

window.addEventListener("load", () => {
	const elements = document.getElementsByClassName("ltx_listing_data");
	const copyButton = '<div class="ltx_listing_copy2clip">' +
		'<button class="ltx_listing_button" onclick="copy2clip(this)" title="Copy to clipboard">' +
		'</button></div>';
	Array.from(elements).forEach(el => {
		if (el.firstChild) {
			el.removeChild(el.firstChild);
		}
		el.insertAdjacentHTML('afterbegin', copyButton);
	});
});
