import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Box, Avatar } from "@mui/material";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import SearchField from "../shared/SearchField";
import ListPagination from "../shared/ListPagination";
import { teachersApi } from "../../utils/api";
import usePagedList from "../../utils/usePagedList";
import { formatPhoneNumber } from "../../utils/phoneFormatter";
import { useAuth } from "../../contexts/AuthContext";

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
	const { user } = useAuth();
	const isAdmin = user?.role === "admin";
	const navigate = useNavigate();
	const list = usePagedList(teachersApi.list);
	const [showForm, setShowForm] = useState(false);
	const [deleteTarget, setDeleteTarget] = useState(null);

	const handleCreate = async (formData) => {
		await teachersApi.create(formData);
		list.reload();
	};

	const handleDelete = async () => {
		if (deleteTarget) {
			await teachersApi.delete(deleteTarget.id);
			setDeleteTarget(null);
			list.reload();
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
				onAdd={isAdmin ? () => setShowForm(true) : undefined}
				addLabel="Add Teacher"
			/>

			<SearchField
				value={list.query}
				onChange={list.setQuery}
				placeholder="Search name, email, phone"
				total={list.total}
				noun="teachers"
			/>
			<DataTable
				columns={columns}
				data={list.rows}
				loading={list.initialLoading}
				onDelete={isAdmin ? setDeleteTarget : undefined}
				onRowClick={(row) => navigate(`/teachers/${row.id}`)}
				emptyMessage={list.query ? `No teachers match "${list.query}".` : "No teachers yet. Add your first teacher to get started."}
			/>
			<ListPagination list={list} />

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
