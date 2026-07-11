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
import ComposeEmailDialog from "../shared/ComposeEmailDialog";
import TokenEditor from "../shared/TokenEditor";
import { emailsApi, emailTemplatesApi, formTemplatesApi, parentsApi } from "../../utils/api";

const STATUS_COLORS = { sent: "success", failed: "error", bounced: "error", queued: "warning", draft: "info" };

function TemplateDialog({ open, onClose, initial, knownKeys, onSaved }) {
	const [form, setForm] = useState({
		key: initial?.key || "",
		name: initial?.name || "",
		subject: initial?.subject || "",
		body: initial?.body || "",
	});
	const [error, setError] = useState(null);
	const [busy, setBusy] = useState(false);
	const subjectEditor = useRef(null);
	const bodyEditor = useRef(null);
	const lastFocused = useRef("body");

	const set = (name, value) => setForm((prev) => ({ ...prev, [name]: value }));
	const tokens = form.key ? knownKeys[form.key] || [] : [];

	const insertToken = (token) => {
		const editor = lastFocused.current === "subject" ? subjectEditor : bodyEditor;
		editor.current?.insertToken(token);
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
						{form.key ? (
							<>
								<TokenEditor
									ref={subjectEditor}
									label="Subject"
									value={form.subject}
									onChange={(v) => set("subject", v)}
									onFocus={() => (lastFocused.current = "subject")}
								/>
								<TokenEditor
									ref={bodyEditor}
									label="Body"
									value={form.body}
									onChange={(v) => set("body", v)}
									onFocus={() => (lastFocused.current = "body")}
									multiline
									minRows={14}
								/>
							</>
						) : (
							<>
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
								/>
							</>
						)}
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
											label={t.replace(/_/g, " ")}
											onClick={() => insertToken(t)}
											clickable
											color="success"
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
							helperText="Formatting: # / ## / ### headings, **bold**, - bullets. Fill-in fields: [[text:key|Label]] (end the label with * to make it required), [[textarea:key|Label]], [[checkbox:key|Label]], [[require-one:key1,key2|Message]] for a required choice, [[payment-plans]] for the program's payment plan options from the database, and [[signature]] where the parent signs."
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
				<ComposeEmailDialog
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
