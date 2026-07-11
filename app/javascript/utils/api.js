import { getCsrfToken, refreshCsrfToken } from "./csrf";

async function request(url, options = {}) {
	const headers = {
		"Content-Type": "application/json",
		"X-CSRF-Token": getCsrfToken(),
		...options.headers,
	};

	const response = await fetch(url, {
		...options,
		headers,
		credentials: "same-origin",
	});

	if (response.status === 401) {
		// Never hard-reload here: on a public page that calls a protected
		// endpoint, reloading re-triggers the 401 and produces an infinite
		// reload loop (violent flashing). Inside the authenticated app, send the
		// user to the login page once; on public pages, surface the error.
		const path = window.location.pathname;
		const publicPrefixes = ["/login", "/enroll", "/forgot-password", "/reset-password", "/meetings", "/payment"];
		const onPublicPage = publicPrefixes.some((p) => path === p || path.startsWith(`${p}/`) || path.startsWith(p));
		if (!onPublicPage) {
			window.location.assign("/login");
			return;
		}
		throw new Error("Unauthorized");
	}

	if (response.status === 422) {
		await refreshCsrfToken();
		const retryResponse = await fetch(url, {
			...options,
			headers: {
				...headers,
				"X-CSRF-Token": getCsrfToken(),
			},
			credentials: "same-origin",
		});
		if (!retryResponse.ok) {
			const error = await retryResponse.json();
			throw new Error(error.errors?.join(", ") || "Request failed");
		}
		return retryResponse.status === 204 ? null : retryResponse.json();
	}

	if (!response.ok) {
		const error = await response.json().catch(() => ({}));
		throw new Error(error.errors?.join(", ") || error.error || "Request failed");
	}

	return response.status === 204 ? null : response.json();
}

export const api = {
	get: (url) => request(url),
	post: (url, data) => request(url, { method: "POST", body: JSON.stringify(data) }),
	patch: (url, data) => request(url, { method: "PATCH", body: JSON.stringify(data) }),
	delete: (url) => request(url, { method: "DELETE" }),
};

// Resource-specific API calls
export const familiesApi = {
	list: () => api.get("/api/families"),
	get: (id) => api.get(`/api/families/${id}`),
	create: (data) => api.post("/api/families", { family: data }),
	delete: (id) => api.delete(`/api/families/${id}`),
};

export const parentsApi = {
	list: () => api.get("/api/parents"),
	get: (id) => api.get(`/api/parents/${id}`),
	create: (data) => api.post("/api/parents", { parent: data }),
	update: (id, data) => api.patch(`/api/parents/${id}`, { parent: data }),
	delete: (id) => api.delete(`/api/parents/${id}`),
};

export const childrenApi = {
	list: () => api.get("/api/children"),
	get: (id) => api.get(`/api/children/${id}`),
	create: (data) => api.post("/api/children", { child: data }),
	delete: (id) => api.delete(`/api/children/${id}`),
};

export const programsApi = {
	list: () => api.get("/api/programs"),
	get: (id) => api.get(`/api/programs/${id}`),
	// Public (no auth) — used by the enrollment application page
	getPublic: (id) => api.get(`/api/public/programs/${id}`),
	create: (data) => api.post("/api/programs", { program: data }),
	update: (id, data) => api.patch(`/api/programs/${id}`, { program: data }),
	delete: (id) => api.delete(`/api/programs/${id}`),
	assignTeacher: (id, teacherId) => api.post(`/api/programs/${id}/assign_teacher`, { teacher_id: teacherId }),
	unassignTeacher: (id, teacherId) => api.delete(`/api/programs/${id}/unassign_teacher?teacher_id=${teacherId}`),
	sendEnrollmentInvite: (id, recipients) => api.post(`/api/programs/${id}/send_enrollment_invite`, { recipients }),
	generateClasses: (id, data) => api.post(`/api/programs/${id}/generate_classes`, data),
};

export const programClassesApi = {
	list: (programId) => api.get(`/api/program_classes${programId ? `?program_id=${programId}` : ""}`),
	get: (id) => api.get(`/api/program_classes/${id}`),
	create: (data) => api.post("/api/program_classes", { program_class: data }),
	update: (id, data) => api.patch(`/api/program_classes/${id}`, { program_class: data }),
	delete: (id) => api.delete(`/api/program_classes/${id}`),
	assignTeacher: (id, teacherId) => api.post(`/api/program_classes/${id}/assign_teacher`, { teacher_id: teacherId }),
	unassignTeacher: (id, teacherId) => api.delete(`/api/program_classes/${id}/unassign_teacher?teacher_id=${teacherId}`),
};

export const programEnrollmentsApi = {
	list: (filters = {}) => {
		const params = new URLSearchParams();
		if (filters.programId) params.append("program_id", filters.programId);
		if (filters.childId) params.append("child_id", filters.childId);
		const query = params.toString();
		return api.get(`/api/program_enrollments${query ? `?${query}` : ""}`);
	},
	get: (id) => api.get(`/api/program_enrollments/${id}`),
	create: (data) => api.post("/api/program_enrollments", { program_enrollment: data }),
	update: (id, data) => api.patch(`/api/program_enrollments/${id}`, { program_enrollment: data }),
	delete: (id) => api.delete(`/api/program_enrollments/${id}`),
};

export const paymentsApi = {
	list: (enrollmentId) => api.get(`/api/payments${enrollmentId ? `?program_enrollment_id=${enrollmentId}` : ""}`),
	get: (id) => api.get(`/api/payments/${id}`),
	create: (data) => api.post("/api/payments", { payment: data }),
	delete: (id) => api.delete(`/api/payments/${id}`),
	sendInvoice: (id) => api.post(`/api/payments/${id}/send_invoice`),
};

export const reportsApi = {
	weeklyRevenue: () => api.get("/api/reports/weekly_revenue"),
};

export const integrationsApi = {
	// Gmail connection status: { connected, configured, email, connected_at, connected_by }
	gmailStatus: () => api.get("/api/admin/integrations/gmail"),
	disconnectGmail: () => api.delete("/api/admin/integrations/gmail"),
	// Connecting is a full-page redirect through Google's consent screen.
	gmailConnectUrl: "/admin/integrations/gmail/connect",
};

export const locationsApi = {
	list: () => api.get("/api/locations"),
	get: (id) => api.get(`/api/locations/${id}`),
	create: (data) => api.post("/api/locations", { location: data }),
	update: (id, data) => api.patch(`/api/locations/${id}`, { location: data }),
	delete: (id) => api.delete(`/api/locations/${id}`),
};

export const teachersApi = {
	list: () => api.get("/api/teachers"),
	get: (id) => api.get(`/api/teachers/${id}`),
	create: (data) => api.post("/api/teachers", { teacher: data }),
	update: (id, data) => api.patch(`/api/teachers/${id}`, { teacher: data }),
	delete: (id) => api.delete(`/api/teachers/${id}`),
};

export const emailsApi = {
	list: (status) => api.get(`/api/emails${status ? `?status=${status}` : ""}`),
	create: (data) => api.post("/api/emails", { email: data }),
	update: (id, data) => api.patch(`/api/emails/${id}`, { email: data }),
	deliver: (id) => api.post(`/api/emails/${id}/deliver`),
	delete: (id) => api.delete(`/api/emails/${id}`),
};

export const emailTemplatesApi = {
	list: () => api.get("/api/email_templates"),
	create: (data) => api.post("/api/email_templates", { email_template: data }),
	update: (id, data) => api.patch(`/api/email_templates/${id}`, { email_template: data }),
	delete: (id) => api.delete(`/api/email_templates/${id}`),
};

export const portalApi = {
	overview: () => api.get("/api/portal/overview"),
	events: () => api.get("/api/portal/events"),
	payments: () => api.get("/api/portal/payments"),
	forms: () => api.get("/api/portal/forms"),
	signForm: (id, signedByName) => api.post(`/api/portal/forms/${id}/sign`, { signed_by_name: signedByName }),
};

export const formTemplatesApi = {
	list: () => api.get("/api/form_templates"),
	update: (id, data) => api.patch(`/api/form_templates/${id}`, { form_template: data }),
};

export const formSignaturesApi = {
	listByFamily: (familyId) => api.get(`/api/enrollment_form_signatures?family_id=${familyId}`),
	issueForChild: (childId) => api.post("/api/enrollment_form_signatures", { child_id: childId }),
};

export const contentItemsApi = {
	list: () => api.get("/api/content_items"),
	create: (data) => api.post("/api/content_items", { content_item: data }),
	update: (id, data) => api.patch(`/api/content_items/${id}`, { content_item: data }),
	delete: (id) => api.delete(`/api/content_items/${id}`),
};

export const usersApi = {
	list: () => api.get("/api/users"),
	create: (data) => api.post("/api/users", { user: data }),
	update: (id, data) => api.patch(`/api/users/${id}`, { user: data }),
	delete: (id) => api.delete(`/api/users/${id}`),
};

// Enrollment workflow APIs
export const enrollmentApplicationsApi = {
	list: (filters = {}) => {
		const params = new URLSearchParams();
		if (filters.status) params.append("status", filters.status);
		if (filters.programId) params.append("program_id", filters.programId);
		const query = params.toString();
		return api.get(`/api/enrollment_applications${query ? `?${query}` : ""}`);
	},
	counts: () => api.get("/api/enrollment_applications/counts"),
	get: (id) => api.get(`/api/enrollment_applications/${id}`),
	create: (data) => api.post("/api/enrollment_applications", { enrollment_application: data }),
	update: (id, data) => api.patch(`/api/enrollment_applications/${id}`, { enrollment_application: data }),
	markReviewed: (id) => api.post(`/api/enrollment_applications/${id}/mark_reviewed`),
	decline: (id, notes) => api.post(`/api/enrollment_applications/${id}/decline`, { notes }),
	completeMeeting: (id, outcomeNotes) => api.post(`/api/enrollment_applications/${id}/complete_meeting`, { outcome_notes: outcomeNotes }),
	requestFee: (id) => api.post(`/api/enrollment_applications/${id}/request_fee`),
	processFeePayment: (id, data) => api.post(`/api/enrollment_applications/${id}/process_fee_payment`, data),
	sendEnrollmentForms: (id) => api.post(`/api/enrollment_applications/${id}/send_enrollment_forms`),
	confirmEnrollment: (id) => api.post(`/api/enrollment_applications/${id}/confirm_enrollment`),
	updateParentEmail: (id, email) => api.patch(`/api/enrollment_applications/${id}/update_parent_email`, { parent_email: email }),
	updateCustomFees: (id, { customEnrollmentFee, customTuitionAmount }) =>
		api.patch(`/api/enrollment_applications/${id}/update_custom_fees`, {
			custom_enrollment_fee: customEnrollmentFee,
			custom_tuition_amount: customTuitionAmount,
		}),
	sendEmail: (id, emailType) => api.post(`/api/enrollment_applications/${id}/send_email`, { email_type: emailType }),
	sendMeetingInvite: (id, { locationId, proposedDates, notes }) =>
		api.post(`/api/enrollment_applications/${id}/send_meeting_invite`, {
			location_id: locationId,
			proposed_dates: proposedDates,
			notes,
		}),
};

export const eventsApi = {
	list: (filters = {}) => {
		const params = new URLSearchParams();
		if (filters.status) params.append("status", filters.status);
		if (filters.eventType) params.append("event_type", filters.eventType);
		if (filters.eventableType) params.append("eventable_type", filters.eventableType);
		if (filters.eventableId) params.append("eventable_id", filters.eventableId);
		const query = params.toString();
		return api.get(`/api/events${query ? `?${query}` : ""}`);
	},
	get: (id) => api.get(`/api/events/${id}`),
	create: (data) => api.post("/api/events", { event: data }),
	update: (id, data) => api.patch(`/api/events/${id}`, { event: data }),
	complete: (id, outcomeNotes) => api.post(`/api/events/${id}/complete`, { outcome_notes: outcomeNotes }),
	cancel: (id, reason) => api.post(`/api/events/${id}/cancel`, { reason }),
	confirm: (id) => api.post(`/api/events/${id}/confirm`),
};

export const paymentPlansApi = {
	list: (programId, activeOnly = false) => {
		const params = new URLSearchParams();
		if (programId) params.append("program_id", programId);
		if (activeOnly) params.append("active", "true");
		const query = params.toString();
		return api.get(`/api/payment_plans${query ? `?${query}` : ""}`);
	},
	get: (id) => api.get(`/api/payment_plans/${id}`),
	create: (data) => api.post("/api/payment_plans", { payment_plan: data }),
	update: (id, data) => api.patch(`/api/payment_plans/${id}`, { payment_plan: data }),
	delete: (id) => api.delete(`/api/payment_plans/${id}`),
};

export const enrollmentPaymentPlansApi = {
	get: (id) => api.get(`/api/enrollment_payment_plans/${id}`),
	create: (data) => api.post("/api/enrollment_payment_plans", { enrollment_payment_plan: data }),
	recordEnrollmentFee: (id, data) => api.post(`/api/enrollment_payment_plans/${id}/record_enrollment_fee`, data),
	recordInstallmentPayment: (id, data) => api.post(`/api/enrollment_payment_plans/${id}/record_installment_payment`, data),
};
