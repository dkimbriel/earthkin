import { useState, useEffect } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
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
	Typography,
} from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import DataTable from "../shared/DataTable";
import ConfirmDialog from "../shared/ConfirmDialog";
import ComposeEmailDialog from "../shared/ComposeEmailDialog";
import { emailsApi, emailTemplatesApi, formTemplatesApi, parentsApi } from "../../utils/api";

const STATUS_COLORS = { sent: "success", failed: "error", bounced: "error", queued: "warning", draft: "info" };

const TAB_NAMES = ["log", "drafts", "templates", "forms"];

export default function EmailsPage() {
	const navigate = useNavigate();
	const [searchParams, setSearchParams] = useSearchParams();
	const tab = Math.max(0, TAB_NAMES.indexOf(searchParams.get("tab")));

	const [emails, setEmails] = useState([]);
	const [templates, setTemplates] = useState([]);
	const [parents, setParents] = useState([]);
	const [loading, setLoading] = useState(true);
	const [showCompose, setShowCompose] = useState(false);
	const [editDraft, setEditDraft] = useState(null);
	const [viewEmail, setViewEmail] = useState(null);
	const [formTemplates, setFormTemplates] = useState([]);
	const [deleteTarget, setDeleteTarget] = useState(null);

	const setTab = (index) => {
		if (index === 0) setSearchParams({});
		else setSearchParams({ tab: TAB_NAMES[index] });
	};

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
			setFormTemplates(formTemplateData.forms);
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
					<Button variant="contained" startIcon={<AddIcon />} onClick={() => navigate("/emails/templates/new")}>
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
					onRowClick={(row) => navigate(`/emails/templates/${row.id}/edit`)}
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
					onRowClick={(row) => navigate(`/emails/forms/${row.id}/edit`)}
					emptyMessage="Forms appear here once loaded."
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
