
function updateHeader() {
	let offset = header.offsetHeight - navigation.offsetHeight;
	
	if (window.scrollY > offset) {
		header.style.paddingBottom = navigation.offsetHeight + "px";
		header.classList.add("sticky");
	} else {
		header.classList.remove("sticky");
		header.style.paddingBottom = null;
	}
	
	//console.log("scroll offset", offset, "header offset height", header.offsetHeight);
}

document.addEventListener('scroll', updateHeader);
window.addEventListener('load', updateHeader);
