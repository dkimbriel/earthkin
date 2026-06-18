import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Box, Avatar } from "@mui/material";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import { teachersApi } from "../../utils/api";
import { formatPhoneNumber } from "../../utils/phoneFormatter";

const columns = [
	{
		key: "avatar",
		label: "",
		render: (row) => (
			<Avatar
				src={row.avatar_url}
				alt={row.full_name}
				sx={{ width: 32, height: 32 }}
			>
				{row.first_name?.[0]}{row.last_name?.[0]}
			</Avatar>
		),
	},
	{
		key: "name",
		label: "Name",
		render: (row) => row.full_name,
	},
	{ key: "email", label: "Email" },
	{ key: "phone", label: "Phone", render: (row) => row.phone ? formatPhoneNumber(row.phone) : "—" },
	{
		key: "programs",
		label: "Programs",
		render: (row) => row.programs?.length || 0,
	},
];

export default function TeachersPage() {
	const navigate = useNavigate();
	const [teachers, setTeachers] = useState([]);
	const [loading, setLoading] = useState(true);
	const [showForm, setShowForm] = useState(false);
	const [deleteTarget, setDeleteTarget] = useState(null);

	const loadTeachers = async () => {
		setLoading(true);
		try {
			const data = await teachersApi.list();
			setTeachers(data);
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		loadTeachers();
	}, []);

	const handleCreate = async (formData) => {
		await teachersApi.create(formData);
		loadTeachers();
	};

	const handleDelete = async () => {
		if (deleteTarget) {
			await teachersApi.delete(deleteTarget.id);
			setDeleteTarget(null);
			loadTeachers();
		}
	};

	const formFields = [
		{ name: "first_name", label: "First Name", required: true },
		{ name: "last_name", label: "Last Name", required: true },
		{ name: "email", label: "Email", type: "email", required: true },
		{ name: "phone", label: "Phone" },
		{ name: "bio", label: "Bio", multiline: true, rows: 3 },
	];

	return (
		<Box>
			<PageHeader
				title="Teachers"
				onAdd={() => setShowForm(true)}
				addLabel="Add Teacher"
			/>

			<DataTable
				columns={columns}
				data={teachers}
				loading={loading}
				onDelete={setDeleteTarget}
				onRowClick={(row) => navigate(`/teachers/${row.id}`)}
				emptyMessage="No teachers yet. Add your first teacher to get started."
			/>

			<FormDialog
				open={showForm}
				onClose={() => setShowForm(false)}
				onSubmit={handleCreate}
				title="Add Teacher"
				fields={formFields}
			/>

			<ConfirmDialog
				open={!!deleteTarget}
				onClose={() => setDeleteTarget(null)}
				onConfirm={handleDelete}
				title="Delete Teacher"
				message={`Are you sure you want to delete ${deleteTarget?.full_name}? This will remove them from all programs and classes.`}
			/>
		</Box>
	);
}
