import { useState } from "react";
import {
	Dialog,
	DialogTitle,
	DialogContent,
	DialogActions,
	Button,
	TextField,
	MenuItem,
	Box,
	Alert,
} from "@mui/material";
import { emailsApi } from "../../utils/api";

// Compose a manual email: used standalone on the Emails page (with template
// and parent pickers) and from an application's Communications tab (prefilled
// with the workflow email, tokens already resolved).
export default function ComposeEmailDialog({
	open,
	onClose,
	initial,
	templates = [],
	parents = [],
	showPickers = true,
	onSaved,
	onSent,
}) {
	const [form, setForm] = useState({
		recipient: initial?.recipient || "",
		subject: initial?.subject || "",
		body: initial?.body || "",
		template_pick: "",
		parent_pick: "",
	});
	const [error, setError] = useState(null);
	const [busy, setBusy] = useState(false);

	const set = (name, value) => setForm((prev) => ({ ...prev, [name]: value }));

	const applyTemplate = (templateId) => {
		const t = templates.find((x) => x.id === templateId);
		if (t) {
			setForm((prev) => ({ ...prev, template_pick: templateId, subject: t.subject, body: t.body }));
		}
	};

	const applyParent = (parentId) => {
		const p = parents.find((x) => x.id === parentId);
		setForm((prev) => ({ ...prev, parent_pick: parentId, recipient: p ? p.email : prev.recipient }));
	};

	const persist = async () => {
		const payload = {
			recipient: form.recipient,
			subject: form.subject,
			body: form.body,
			parent_id: form.parent_pick || null,
			email_type: initial?.email_type || null,
			enrollment_application_id: initial?.enrollment_application_id || null,
		};
		if (initial?.id) {
			return emailsApi.update(initial.id, payload);
		}
		return emailsApi.create(payload);
	};

	const handleSaveDraft = async () => {
		setError(null);
		setBusy(true);
		try {
			await persist();
			onSaved();
			onClose();
		} catch (err) {
			setError(err.message);
		} finally {
			setBusy(false);
		}
	};

	const handleSend = async () => {
		setError(null);
		setBusy(true);
		try {
			const saved = await persist();
			await emailsApi.deliver(saved?.id || initial?.id);
			onSent();
			onClose();
		} catch (err) {
			setError(err.message);
		} finally {
			setBusy(false);
		}
	};

	return (
		<Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
			<DialogTitle>{initial?.id ? "Edit Draft" : "New Email"}</DialogTitle>
			<DialogContent>
				{error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
				<Box sx={{ display: "flex", flexDirection: "column", gap: 2, mt: 1 }}>
					{showPickers && (
						<Box sx={{ display: "flex", gap: 2 }}>
							<TextField
								select
								label="Start from template"
								value={form.template_pick}
								onChange={(e) => applyTemplate(e.target.value)}
								fullWidth
							>
								<MenuItem value="">Blank</MenuItem>
								{templates.map((t) => (
									<MenuItem key={t.id} value={t.id}>{t.name}</MenuItem>
								))}
							</TextField>
							<TextField
								select
								label="Send to parent"
								value={form.parent_pick}
								onChange={(e) => applyParent(e.target.value)}
								fullWidth
							>
								<MenuItem value="">Type an address instead</MenuItem>
								{[...parents]
									.sort((a, b) =>
										`${a.first_name} ${a.last_name}`.localeCompare(
											`${b.first_name} ${b.last_name}`,
											undefined,
											{ sensitivity: "base" }
										)
									)
									.map((p) => (
										<MenuItem key={p.id} value={p.id}>
											{p.first_name} {p.last_name} ({p.email})
										</MenuItem>
									))}
							</TextField>
						</Box>
					)}
					<TextField
						label="To"
						type="email"
						value={form.recipient}
						onChange={(e) => set("recipient", e.target.value)}
						required
						fullWidth
					/>
					<TextField
						label="Subject"
						value={form.subject}
						onChange={(e) => set("subject", e.target.value)}
						required
						fullWidth
					/>
					<TextField
						label="Body"
						value={form.body}
						onChange={(e) => set("body", e.target.value)}
						multiline
						rows={12}
						required
						fullWidth
						helperText="Plain text. Blank lines start new paragraphs. Sent with the school's standard email styling."
					/>
				</Box>
			</DialogContent>
			<DialogActions>
				<Button onClick={onClose}>Cancel</Button>
				<Button onClick={handleSaveDraft} disabled={busy}>
					Save Draft
				</Button>
				<Button onClick={handleSend} variant="contained" disabled={busy}>
					{busy ? "Working..." : "Send"}
				</Button>
			</DialogActions>
		</Dialog>
	);
}
