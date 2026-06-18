export function getCsrfToken() {
	const meta = document.querySelector('meta[name="csrf-token"]');
	return meta ? meta.getAttribute("content") : "";
}

export async function refreshCsrfToken() {
	try {
		const response = await fetch("/api/csrf_token");
		const data = await response.json();
		const meta = document.querySelector('meta[name="csrf-token"]');
		if (meta && data.csrf_token) {
			meta.setAttribute("content", data.csrf_token);
		}
	} catch (err) {
		console.error("Failed to refresh CSRF token");
	}
}
