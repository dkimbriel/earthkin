import { useState, useEffect, useRef } from "react";
import {
	Box,
	Chip,
	Tabs,
	Tab,
	Button,
	Dialog,
	DialogTitle,
	DialogContent,
	DialogActions,
	TextField,
	MenuItem,
	Alert,
	Typography,
} from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import DataTable from "../shared/DataTable";
import ConfirmDialog from "../shared/ConfirmDialog";
import { emailsApi, emailTemplatesApi, formTemplatesApi, parentsApi } from "../../utils/api";

const STATUS_COLORS = { sent: "success", failed: "error", bounced: "error", queued: "warning", draft: "info" };

function ComposeDialog({ open, onClose, initial, templates, parents, onSaved, onSent }) {
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
			await emailsApi.deliver(saved.id);
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
							{parents.map((p) => (
								<MenuItem key={p.id} value={p.id}>
									{p.first_name} {p.last_name} ({p.email})
								</MenuItem>
							))}
						</TextField>
					</Box>
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
						rows={10}
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

function TemplateDialog({ open, onClose, initial, knownKeys, onSaved }) {
	const [form, setForm] = useState({
		key: initial?.key || "",
		name: initial?.name || "",
		subject: initial?.subject || "",
		body: initial?.body || "",
	});
	const [error, setError] = useState(null);
	const [busy, setBusy] = useState(false);
	const subjectRef = useRef(null);
	const bodyRef = useRef(null);
	const lastFocused = useRef("body");

	const set = (name, value) => setForm((prev) => ({ ...prev, [name]: value }));
	const tokens = form.key ? knownKeys[form.key] || [] : [];

	const insertToken = (token) => {
		const field = lastFocused.current === "subject" ? "subject" : "body";
		const ref = field === "subject" ? subjectRef : bodyRef;
		const input = ref.current;
		const text = `{{${token}}}`;
		const value = form[field];
		const start = input?.selectionStart ?? value.length;
		const end = input?.selectionEnd ?? value.length;
		const next = value.slice(0, start) + text + value.slice(end);
		set(field, next);
		// Restore focus and put the cursor right after the inserted token.
		setTimeout(() => {
			if (!input) return;
			input.focus();
			const pos = start + text.length;
			input.setSelectionRange(pos, pos);
		}, 0);
	};

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setBusy(true);
		try {
			if (initial?.id) {
				await emailTemplatesApi.update(initial.id, form);
			} else {
				await emailTemplatesApi.create(form);
			}
			onSaved();
			onClose();
		} catch (err) {
			setError(err.message);
		} finally {
			setBusy(false);
		}
	};

	return (
		<Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
			<form onSubmit={handleSubmit}>
				<DialogTitle>{initial?.id ? `Edit ${initial.name}` : "New Template"}</DialogTitle>
				<DialogContent>
					{error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
					<Box sx={{ display: "flex", flexDirection: "column", gap: 2, mt: 1 }}>
						<TextField
							select
							label="Workflow email"
							value={form.key}
							onChange={(e) => set("key", e.target.value)}
							fullWidth
							disabled={!!initial?.key}
							helperText={
								initial?.key
									? "This template is the wording used for this workflow email."
									: "Pick a workflow email to edit its wording, or leave as 'None' for a reusable manual-email template."
							}
						>
							<MenuItem value="">None (manual email template)</MenuItem>
							{Object.keys(knownKeys).map((k) => (
								<MenuItem key={k} value={k}>{k.replace(/_/g, " ")}</MenuItem>
							))}
						</TextField>
						<TextField
							label="Template Name"
							value={form.name}
							onChange={(e) => set("name", e.target.value)}
							required
							fullWidth
						/>
						<TextField
							label="Subject"
							value={form.subject}
							onChange={(e) => set("subject", e.target.value)}
							onFocus={() => (lastFocused.current = "subject")}
							inputRef={subjectRef}
							required
							fullWidth
						/>
						<TextField
							label="Body"
							value={form.body}
							onChange={(e) => set("body", e.target.value)}
							onFocus={() => (lastFocused.current = "body")}
							inputRef={bodyRef}
							multiline
							rows={14}
							required
							fullWidth
						/>
						{tokens.length > 0 && (
							<Box>
								<Typography variant="caption" color="text.secondary">
									Tokens — click to insert at the cursor (filled in automatically when the email is sent):
								</Typography>
								<Box sx={{ display: "flex", gap: 1, flexWrap: "wrap", mt: 0.5 }}>
									{tokens.map((t) => (
										<Chip
											key={t}
											size="small"
											label={`{{${t}}}`}
											onClick={() => insertToken(t)}
											clickable
											color="primary"
											variant="outlined"
										/>
									))}
								</Box>
							</Box>
						)}
					</Box>
				</DialogContent>
				<DialogActions>
					<Button onClick={onClose}>Cancel</Button>
					<Button type="submit" variant="contained" disabled={busy}>
						{busy ? "Saving..." : "Save"}
					</Button>
				</DialogActions>
			</form>
		</Dialog>
	);
}

function FormTemplateDialog({ open, onClose, initial, onSaved }) {
	const [form, setForm] = useState({ name: initial.name, body: initial.body });
	const [error, setError] = useState(null);
	const [busy, setBusy] = useState(false);

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setBusy(true);
		try {
			await formTemplatesApi.update(initial.id, form);
			onSaved();
			onClose();
		} catch (err) {
			setError(err.message);
		} finally {
			setBusy(false);
		}
	};

	return (
		<Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
			<form onSubmit={handleSubmit}>
				<DialogTitle>Edit {initial.name}</DialogTitle>
				<DialogContent>
					{error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
					<Box sx={{ display: "flex", flexDirection: "column", gap: 2, mt: 1 }}>
						<TextField
							label="Form Name"
							value={form.name}
							onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))}
							required
							fullWidth
						/>
						<TextField
							label="Form Text (what parents read and sign)"
							value={form.body}
							onChange={(e) => setForm((p) => ({ ...p, body: e.target.value }))}
							multiline
							rows={16}
							required
							fullWidth
						/>
					</Box>
				</DialogContent>
				<DialogActions>
					<Button onClick={onClose}>Cancel</Button>
					<Button type="submit" variant="contained" disabled={busy}>
						{busy ? "Saving..." : "Save"}
					</Button>
				</DialogActions>
			</form>
		</Dialog>
	);
}

export default function EmailsPage() {
	const [tab, setTab] = useState(0);
	const [emails, setEmails] = useState([]);
	const [templates, setTemplates] = useState([]);
	const [knownKeys, setKnownKeys] = useState({});
	const [parents, setParents] = useState([]);
	const [loading, setLoading] = useState(true);
	const [showCompose, setShowCompose] = useState(false);
	const [editDraft, setEditDraft] = useState(null);
	const [viewEmail, setViewEmail] = useState(null);
	const [showTemplateForm, setShowTemplateForm] = useState(false);
	const [editTemplate, setEditTemplate] = useState(null);
	const [formTemplates, setFormTemplates] = useState([]);
	const [editFormTemplate, setEditFormTemplate] = useState(null);
	const [deleteTarget, setDeleteTarget] = useState(null);

	const load = async () => {
		setLoading(true);
		try {
			const [emailData, templateData, formTemplateData] = await Promise.all([
				emailsApi.list(),
				emailTemplatesApi.list(),
				formTemplatesApi.list(),
			]);
			setEmails(emailData);
			setTemplates(templateData.templates);
			setKnownKeys(templateData.known_keys);
			setFormTemplates(formTemplateData);
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		load();
		parentsApi.list().then(setParents).catch(() => {});
	}, []);

	const emailColumns = [
		{ key: "recipient", label: "To" },
		{ key: "subject", label: "Subject" },
		{
			key: "email_type",
			label: "Type",
			render: (row) => row.email_type?.replace(/_/g, " "),
		},
		{
			key: "status",
			label: "Status",
			render: (row) => (
				<Chip size="small" label={row.status} color={STATUS_COLORS[row.status] || "default"} />
			),
		},
		{
			key: "created_at",
			label: "Date",
			render: (row) => new Date(row.sent_at || row.created_at).toLocaleString(),
		},
	];

	const templateColumns = [
		{ key: "name", label: "Name" },
		{
			key: "key",
			label: "Workflow Email",
			render: (row) =>
				row.key ? <Chip size="small" color="primary" label={row.key.replace(/_/g, " ")} /> : "manual only",
		},
		{ key: "subject", label: "Subject" },
	];

	const drafts = emails.filter((e) => e.status === "draft");
	const log = emails.filter((e) => e.status !== "draft");

	return (
		<Box>
			<Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 2 }}>
				<Typography variant="h5" component="h1">Emails</Typography>
				{tab === 2 && (
					<Button variant="contained" startIcon={<AddIcon />} onClick={() => setShowTemplateForm(true)}>
						New Template
					</Button>
				)}
				{tab < 2 && (
					<Button variant="contained" startIcon={<AddIcon />} onClick={() => setShowCompose(true)}>
						New Email
					</Button>
				)}
			</Box>

			<Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }}>
				<Tab label={`Sent & Log (${log.length})`} />
				<Tab label={`Drafts (${drafts.length})`} />
				<Tab label={`Templates (${templates.length})`} />
				<Tab label="Enrollment Forms" />
			</Tabs>

			{tab === 0 && (
				<DataTable
					columns={emailColumns}
					data={log}
					loading={loading}
					onRowClick={(row) => setViewEmail(row)}
					emptyMessage="No emails sent yet."
				/>
			)}

			{tab === 1 && (
				<DataTable
					columns={emailColumns}
					data={drafts}
					loading={loading}
					onRowClick={(row) => setEditDraft(row)}
					onDelete={(row) => setDeleteTarget({ type: "email", row })}
					emptyMessage="No drafts. Start one with New Email."
				/>
			)}

			{tab === 2 && (
				<DataTable
					columns={templateColumns}
					data={templates}
					loading={loading}
					onRowClick={(row) => setEditTemplate(row)}
					onDelete={(row) => setDeleteTarget({ type: "template", row })}
					emptyMessage="No templates yet. Templates can override workflow emails or seed manual emails."
				/>
			)}

			{tab === 3 && (
				<DataTable
					columns={[
						{ key: "name", label: "Form" },
						{
							key: "body",
							label: "Text",
							render: (row) => `${row.body.slice(0, 80)}${row.body.length > 80 ? "…" : ""}`,
						},
					]}
					data={formTemplates}
					loading={loading}
					onRowClick={(row) => setEditFormTemplate(row)}
					emptyMessage="Forms appear here once loaded."
				/>
			)}

			{editFormTemplate && (
				<FormTemplateDialog
					key={editFormTemplate.id}
					open
					onClose={() => setEditFormTemplate(null)}
					initial={editFormTemplate}
					onSaved={load}
				/>
			)}

			{(showCompose || editDraft) && (
				<ComposeDialog
					key={editDraft?.id || "new"}
					open
					onClose={() => {
						setShowCompose(false);
						setEditDraft(null);
					}}
					initial={editDraft}
					templates={templates}
					parents={parents}
					onSaved={load}
					onSent={load}
				/>
			)}

			{(showTemplateForm || editTemplate) && (
				<TemplateDialog
					key={editTemplate?.id || "new"}
					open
					onClose={() => {
						setShowTemplateForm(false);
						setEditTemplate(null);
					}}
					initial={editTemplate}
					knownKeys={knownKeys}
					onSaved={load}
				/>
			)}

			{viewEmail && (
				<Dialog open onClose={() => setViewEmail(null)} maxWidth="md" fullWidth>
					<DialogTitle>{viewEmail.subject}</DialogTitle>
					<DialogContent>
						<Typography variant="body2" color="text.secondary" gutterBottom>
							To: {viewEmail.recipient} — {viewEmail.status}
							{viewEmail.error_message ? ` — ${viewEmail.error_message}` : ""}
						</Typography>
						<Box
							sx={{ border: "1px solid", borderColor: "divider", borderRadius: 1, p: 2 }}
							dangerouslySetInnerHTML={{ __html: viewEmail.html_body || "<em>No preview available</em>" }}
						/>
					</DialogContent>
					<DialogActions>
						<Button onClick={() => setViewEmail(null)}>Close</Button>
					</DialogActions>
				</Dialog>
			)}

			<ConfirmDialog
				open={!!deleteTarget}
				onClose={() => setDeleteTarget(null)}
				onConfirm={async () => {
					if (deleteTarget.type === "email") {
						await emailsApi.delete(deleteTarget.row.id);
					} else {
						await emailTemplatesApi.delete(deleteTarget.row.id);
					}
					setDeleteTarget(null);
					load();
				}}
				title={
					deleteTarget?.type === "template"
						? deleteTarget?.row?.key ? "Reset Template" : "Delete Template"
						: "Delete Draft"
				}
				message={
					deleteTarget?.type === "template"
						? deleteTarget?.row?.key
							? `Reset "${deleteTarget?.row?.name}" to its default wording? Your edits will be lost.`
							: `Delete template "${deleteTarget?.row?.name}"?`
						: `Delete this draft to ${deleteTarget?.row?.recipient}?`
				}
			/>
		</Box>
	);
}
