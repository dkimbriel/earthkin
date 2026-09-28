import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Box, Chip, Typography, Tooltip, Alert, Snackbar } from "@mui/material";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import SearchField from "../shared/SearchField";
import ListPagination from "../shared/ListPagination";
import { programsApi } from "../../utils/api";
import usePagedList from "../../utils/usePagedList";
import { useAuth } from "../../contexts/AuthContext";

function EnrollmentProgress({ confirmed, pending, capacity }) {
	const total = confirmed + pending;
	const confirmedPct = capacity ? (confirmed / capacity) * 100 : 0;
	const pendingPct = capacity ? (pending / capacity) * 100 : 0;
	const isOverCapacity = total > capacity;

	return (
		<Box sx={{ minWidth: 120 }}>
			<Box sx={{ display: "flex", justifyContent: "space-between", mb: 0.5 }}>
				<Typography variant="caption">
					{confirmed}/{capacity}
				</Typography>
				{pending > 0 && (
					<Typography variant="caption" color="warning.main">
						+{pending} pending
					</Typography>
				)}
			</Box>
			<Tooltip title={`${confirmed} confirmed, ${pending} pending, ${Math.max(0, capacity - total)} available`}>
				<Box
					sx={{
						height: 8,
						borderRadius: 1,
						bgcolor: "grey.200",
						overflow: "hidden",
						display: "flex",
					}}
				>
					<Box
						sx={{
							width: `${Math.min(confirmedPct, 100)}%`,
							bgcolor: isOverCapacity ? "error.main" : "success.main",
							transition: "width 0.3s",
						}}
					/>
					<Box
						sx={{
							width: `${Math.min(pendingPct, 100 - confirmedPct)}%`,
							bgcolor: "warning.main",
							transition: "width 0.3s",
						}}
					/>
				</Box>
			</Tooltip>
		</Box>
	);
}

const columns = [
	{ key: "name", label: "Program Name" },
	{
		key: "dates",
		label: "Dates",
		render: (row) => {
			const start = row.start_date ? new Date(row.start_date).toLocaleDateString() : "";
			const end = row.end_date ? new Date(row.end_date).toLocaleDateString() : "";
			return start && end ? `${start} – ${end}` : start || end || "—";
		},
	},
	{
		key: "classes",
		label: "Classes",
		render: (row) => row.program_classes?.length || 0,
	},
	{
		key: "enrollment",
		label: "Enrollment",
		render: (row) => {
			const confirmed = row.enrolled_count || 0;
			const pending = row.pending_count || 0;
			const capacity = row.capacity;
			if (capacity) {
				return (
					<EnrollmentProgress
						confirmed={confirmed}
						pending={pending}
						capacity={capacity}
					/>
				);
			}
			return pending > 0 ? `${confirmed} (+${pending} pending)` : confirmed;
		},
	},
];

const formFields = [
	{ name: "name", label: "Program Name", required: true },
	{ name: "description", label: "Description", multiline: true, rows: 3 },
	{ name: "start_date", label: "Start Date", type: "date" },
	{ name: "end_date", label: "End Date", type: "date" },
	{ name: "capacity", label: "Capacity", type: "number" },
];

export default function ProgramsPage() {
	const { user } = useAuth();
	const isAdmin = user?.role === "admin";
	const navigate = useNavigate();
	const list = usePagedList(programsApi.list);
	const [showForm, setShowForm] = useState(false);
	const [deleteTarget, setDeleteTarget] = useState(null);
	const [deleteError, setDeleteError] = useState(null);

	const handleCreate = async (formData) => {
		await programsApi.create(formData);
		list.reload();
	};

	const handleDelete = async () => {
		if (!deleteTarget) return;
		try {
			await programsApi.delete(deleteTarget.id);
			setDeleteTarget(null);
			list.reload();
		} catch (err) {
			setDeleteTarget(null);
			setDeleteError(err.message);
		}
	};

	return (
		<Box>
			<PageHeader title="Programs" onAdd={isAdmin ? () => setShowForm(true) : undefined} addLabel="Add Program" />
			<SearchField
				value={list.query}
				onChange={list.setQuery}
				placeholder="Search programs"
				total={list.total}
				noun="programs"
			/>
			<DataTable
				columns={columns}
				data={list.rows}
				loading={list.initialLoading}
				onDelete={isAdmin ? setDeleteTarget : undefined}
				onRowClick={(row) => navigate(`/programs/${row.id}`)}
				emptyMessage={list.query ? `No programs match "${list.query}".` : "No programs yet. Add one to get started."}
			/>
			<ListPagination list={list} />
			<FormDialog
				open={showForm}
				onClose={() => setShowForm(false)}
				onSubmit={handleCreate}
				title="Add Program"
				fields={formFields}
			/>
			<ConfirmDialog
				open={!!deleteTarget}
				onClose={() => setDeleteTarget(null)}
				onConfirm={handleDelete}
				title="Delete Program"
				message={`Delete "${deleteTarget?.name}"? Its classes and enrollments are removed too, but you can restore it from Recently Deleted. Programs with active enrollments can't be deleted.`}
			/>
			<Snackbar
				open={!!deleteError}
				autoHideDuration={8000}
				onClose={() => setDeleteError(null)}
				anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
			>
				<Alert severity="warning" onClose={() => setDeleteError(null)} sx={{ width: "100%" }}>
					{deleteError}
				</Alert>
			</Snackbar>
		</Box>
	);
}
