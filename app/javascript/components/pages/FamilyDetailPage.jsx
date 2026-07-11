import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
	Box,
	Typography,
	Button,
	Paper,
	Chip,
	Dialog,
	DialogTitle,
	DialogContent,
	DialogActions,
	Table,
	TableHead,
	TableBody,
	TableRow,
	TableCell,
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import { familiesApi, parentsApi, childrenApi, programEnrollmentsApi, formSignaturesApi } from "../../utils/api";
import { useAuth } from "../../contexts/AuthContext";
import FormDocument, { hasFormFields } from "../shared/FormDocument";

const parentColumns = [
	{
		key: "name",
		label: "Name",
		render: (row) => `${row.first_name} ${row.last_name}`,
	},
	{ key: "email", label: "Email" },
	{ key: "phone", label: "Phone" },
];

const childColumns = [
	{
		key: "name",
		label: "Name",
		render: (row) => `${row.first_name} ${row.last_name}`,
	},
];

const enrollmentColumns = [
	{
		key: "child",
		label: "Child",
		render: (row) => row.child ? `${row.child.first_name} ${row.child.last_name}` : "—",
	},
	{
		key: "program",
		label: "Program",
		render: (row) => row.program?.name || "—",
	},
	{
		key: "status",
		label: "Status",
		render: (row) => (
			<Chip
				label={row.status}
				color={row.status === "confirmed" ? "success" : row.status === "pending" ? "warning" : "default"}
				size="small"
			/>
		),
	},
	{
		key: "rate_per_class",
		label: "Rate/Class",
		render: (row) => `$${parseFloat(row.rate_per_class || 0).toFixed(2)}`,
	},
	{
		key: "balance_due",
		label: "Balance Due",
		render: (row) => {
			const balance = parseFloat(row.balance_due) || 0;
			return (
				<Chip
					label={`$${balance.toFixed(2)}`}
					color={balance > 0 ? "warning" : "success"}
					size="small"
				/>
			);
		},
	},
];

export default function FamilyDetailPage() {
	const { id } = useParams();
	const navigate = useNavigate();
	const { user } = useAuth();
	const isAdmin = user?.role === "admin";
	const [family, setFamily] = useState(null);
	const [loading, setLoading] = useState(true);
	const [enrollments, setEnrollments] = useState([]);
	const [enrollmentsLoading, setEnrollmentsLoading] = useState(false);
	const [showParentForm, setShowParentForm] = useState(false);
	const [showChildForm, setShowChildForm] = useState(false);
	const [deleteTarget, setDeleteTarget] = useState(null);
	const [signatures, setSignatures] = useState([]);
	const [auditTarget, setAuditTarget] = useState(null);

	const loadSignatures = async () => {
		try {
			const data = await formSignaturesApi.listByFamily(id);
			setSignatures(data);
		} catch {
			setSignatures([]);
		}
	};

	const loadFamily = async () => {
		setLoading(true);
		try {
			const data = await familiesApi.get(id);
			setFamily(data);
			return data;
		} finally {
			setLoading(false);
		}
	};

	const loadEnrollments = async (familyData) => {
		if (!familyData?.children?.length) {
			setEnrollments([]);
			return;
		}
		setEnrollmentsLoading(true);
		try {
			const enrollmentPromises = familyData.children.map((child) =>
				programEnrollmentsApi.list({ childId: child.id })
			);
			const results = await Promise.all(enrollmentPromises);
			const allEnrollments = results.flat();
			setEnrollments(allEnrollments);
		} finally {
			setEnrollmentsLoading(false);
		}
	};

	useEffect(() => {
		const load = async () => {
			const familyData = await loadFamily();
			await loadEnrollments(familyData);
			await loadSignatures();
		};
		load();
	}, [id]);

	const handleIssueForms = async (childId) => {
		await formSignaturesApi.issueForChild(childId);
		loadSignatures();
	};

	const handleCreateParent = async (formData) => {
		await parentsApi.create({ ...formData, family_id: id });
		loadFamily();
	};

	const handleCreateChild = async (formData) => {
		await childrenApi.create({ ...formData, family_id: id });
		loadFamily();
	};

	const handleDeleteParent = async () => {
		if (deleteTarget?.type === "parent") {
			await parentsApi.delete(deleteTarget.item.id);
			setDeleteTarget(null);
			loadFamily();
		}
	};

	const handleDeleteChild = async () => {
		if (deleteTarget?.type === "child") {
			await childrenApi.delete(deleteTarget.item.id);
			setDeleteTarget(null);
			loadFamily();
		}
	};

	const parentFormFields = [
		{ name: "first_name", label: "First Name", required: true },
		{ name: "last_name", label: "Last Name", required: true },
		{ name: "email", label: "Email", type: "email", required: true },
		{ name: "phone", label: "Phone" },
	];

	const childFormFields = [
		{ name: "first_name", label: "First Name", required: true },
		{ name: "last_name", label: "Last Name", required: true },
	];

	if (loading) {
		return <Typography>Loading...</Typography>;
	}

	if (!family) {
		return <Typography>Family not found</Typography>;
	}

	return (
		<Box>
			<Button startIcon={<ArrowBackIcon />} onClick={() => navigate("/families")} sx={{ mb: 2 }}>
				Back to Families
			</Button>

			<Typography variant="h4" gutterBottom>
				{family.name}
			</Typography>

			<Paper sx={{ p: 3, mb: 3 }}>
				<PageHeader
					title="Parents"
					onAdd={isAdmin ? () => setShowParentForm(true) : undefined}
					addLabel="Add Parent"
				/>
				<DataTable
					columns={parentColumns}
					data={family.parents}
					loading={false}
					onDelete={isAdmin ? (item) => setDeleteTarget({ type: "parent", item }) : undefined}
					onRowClick={isAdmin ? (row) => navigate(`/parents/${row.id}/edit`) : undefined}
					emptyMessage="No parents added yet."
				/>
			</Paper>

			<Paper sx={{ p: 3, mb: 3 }}>
				<PageHeader
					title="Children"
					onAdd={isAdmin ? () => setShowChildForm(true) : undefined}
					addLabel="Add Child"
				/>
				<DataTable
					columns={childColumns}
					data={family.children}
					loading={false}
					onDelete={isAdmin ? (item) => setDeleteTarget({ type: "child", item }) : undefined}
					onRowClick={(row) => navigate(`/children/${row.id}`)}
					emptyMessage="No children added yet."
				/>
			</Paper>

			<Paper sx={{ p: 3, mb: 3 }}>
				<Typography variant="h6" gutterBottom>
					Enrollments
				</Typography>
				<DataTable
					columns={enrollmentColumns}
					data={enrollments}
					loading={enrollmentsLoading}
					onRowClick={(row) => navigate(`/enrollments/${row.id}`, { state: { from: `/families/${id}` } })}
					emptyMessage="No enrollments for this family."
				/>
			</Paper>

			<Paper sx={{ p: 3 }}>
				<Typography variant="h6" gutterBottom>
					Enrollment Paperwork
				</Typography>
				{family.children.length === 0 && (
					<Typography color="text.secondary">Add a child to issue enrollment forms.</Typography>
				)}
				{family.children.map((child) => {
					const childSignatures = signatures.filter((s) => s.child_id === child.id);
					return (
						<Box key={child.id} sx={{ mb: 2 }}>
							<Box sx={{ display: "flex", alignItems: "center", gap: 2, mb: 1 }}>
								<Typography variant="subtitle1">
									{child.first_name} {child.last_name}
								</Typography>
								{isAdmin && childSignatures.length === 0 && (
									<Button size="small" variant="outlined" onClick={() => handleIssueForms(child.id)}>
										Issue Enrollment Forms
									</Button>
								)}
							</Box>
							{childSignatures.length === 0 ? (
								<Typography variant="body2" color="text.secondary">
									No forms issued yet.
								</Typography>
							) : (
								<Box sx={{ display: "flex", gap: 1, flexWrap: "wrap" }}>
									{childSignatures.map((sig) => (
										<Chip
											key={sig.id}
											label={
												sig.status === "signed"
													? `${sig.form_name} — signed by ${sig.signed_by_name} ${new Date(sig.signed_at).toLocaleDateString()}`
													: `${sig.form_name} — awaiting signature`
											}
											color={sig.status === "signed" ? "success" : "warning"}
											variant={sig.status === "signed" ? "filled" : "outlined"}
											size="small"
											onClick={() => setAuditTarget(sig)}
											clickable
										/>
									))}
								</Box>
							)}
						</Box>
					);
				})}
			</Paper>

			{auditTarget && (
				<Dialog open onClose={() => setAuditTarget(null)} maxWidth="md" fullWidth>
					<DialogTitle>
						{auditTarget.form_name} — {auditTarget.child_name}
					</DialogTitle>
					<DialogContent>
						{auditTarget.status === "signed" ? (
							<>
								<Typography sx={{ fontFamily: '"Snell Roundhand", "Brush Script MT", "Segoe Script", cursive', fontSize: "2rem" }}>
									{auditTarget.signed_by_name}
								</Typography>
								<Typography variant="body2" color="text.secondary" gutterBottom>
									Signed by {auditTarget.signed_by_name}
									{auditTarget.signed_by_email ? ` (${auditTarget.signed_by_email})` : ""} on{" "}
									{new Date(auditTarget.signed_at).toLocaleString()}
								</Typography>
							</>
						) : (
							<Typography variant="body2" color="text.secondary" gutterBottom>
								Awaiting signature.
							</Typography>
						)}

						{auditTarget.response_text && (
							<>
								<Typography variant="subtitle2" sx={{ mt: 2 }}>Family's answers</Typography>
								<Paper variant="outlined" sx={{ p: 2, whiteSpace: "pre-wrap", maxHeight: 240, overflow: "auto" }}>
									{auditTarget.response_text}
								</Paper>
							</>
						)}

						{auditTarget.audit_log?.length > 0 && (
							<>
								<Typography variant="subtitle2" sx={{ mt: 2 }}>Signing history</Typography>
								<Table size="small">
									<TableHead>
										<TableRow>
											<TableCell>Event</TableCell>
											<TableCell>When</TableCell>
											<TableCell>Who</TableCell>
											<TableCell>IP Address</TableCell>
										</TableRow>
									</TableHead>
									<TableBody>
										{auditTarget.audit_log.map((entry, i) => (
											<TableRow key={i}>
												<TableCell>
													<Chip
														size="small"
														label={entry.event}
														color={entry.event === "signed" ? "success" : entry.event === "viewed" ? "info" : "default"}
													/>
												</TableCell>
												<TableCell>{new Date(entry.at).toLocaleString()}</TableCell>
												<TableCell>{entry.by || entry.email || "—"}</TableCell>
												<TableCell>{entry.ip || "—"}</TableCell>
											</TableRow>
										))}
									</TableBody>
								</Table>
								{auditTarget.audit_log.find((e) => e.document_sha256) && (
									<Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: "block" }}>
										Document fingerprint (SHA-256):{" "}
										{auditTarget.audit_log.find((e) => e.document_sha256).document_sha256}
									</Typography>
								)}
							</>
						)}

						{auditTarget.form_body_snapshot && (
							<>
								<Typography variant="subtitle2" sx={{ mt: 2 }}>Form as signed</Typography>
								<Paper
									variant="outlined"
									sx={{
										p: 3,
										whiteSpace: hasFormFields(auditTarget.form_body_snapshot) ? "normal" : "pre-wrap",
										maxHeight: 360,
										overflow: "auto",
									}}
								>
									{hasFormFields(auditTarget.form_body_snapshot) ? (
										<FormDocument
											body={auditTarget.form_body_snapshot}
											values={auditTarget.form_fields || {}}
											readOnly
											signatureName={auditTarget.signed_by_name}
											signedAt={auditTarget.signed_at}
										/>
									) : (
										auditTarget.form_body_snapshot
									)}
								</Paper>
							</>
						)}
					</DialogContent>
					<DialogActions>
						<Button component="a" href={`/api/enrollment_form_signatures/${auditTarget.id}/pdf`}>
							Download PDF
						</Button>
						<Button onClick={() => setAuditTarget(null)}>Close</Button>
					</DialogActions>
				</Dialog>
			)}

			<FormDialog
				open={showParentForm}
				onClose={() => setShowParentForm(false)}
				onSubmit={handleCreateParent}
				title="Add Parent"
				fields={parentFormFields}
			/>

			<FormDialog
				open={showChildForm}
				onClose={() => setShowChildForm(false)}
				onSubmit={handleCreateChild}
				title="Add Child"
				fields={childFormFields}
			/>

			<ConfirmDialog
				open={deleteTarget?.type === "parent"}
				onClose={() => setDeleteTarget(null)}
				onConfirm={handleDeleteParent}
				title="Delete Parent"
				message={`Are you sure you want to delete ${deleteTarget?.item?.first_name} ${deleteTarget?.item?.last_name}?`}
			/>

			<ConfirmDialog
				open={deleteTarget?.type === "child"}
				onClose={() => setDeleteTarget(null)}
				onConfirm={handleDeleteChild}
				title="Delete Child"
				message={`Are you sure you want to delete ${deleteTarget?.item?.first_name} ${deleteTarget?.item?.last_name}? This will also delete their program enrollments.`}
			/>
		</Box>
	);
}
