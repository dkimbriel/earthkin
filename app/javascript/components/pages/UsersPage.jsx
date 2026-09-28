import { useState, useEffect } from "react";
import { Box, Chip } from "@mui/material";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import SearchField from "../shared/SearchField";
import ListPagination from "../shared/ListPagination";
import { usersApi, teachersApi } from "../../utils/api";
import usePagedList from "../../utils/usePagedList";
import { useAuth } from "../../contexts/AuthContext";

const ROLE_COLORS = { admin: "primary", teacher: "success", parent: "default" };

const columns = [
	{ key: "email", label: "Email" },
	{
		key: "role",
		label: "Role",
		render: (row) => (
			<Chip label={row.role} color={ROLE_COLORS[row.role] || "default"} size="small" />
		),
	},
	{
		key: "display_name",
		label: "Linked To",
		render: (row) => (row.display_name !== row.email ? row.display_name : "—"),
	},
	{
		key: "created_at",
		label: "Created",
		render: (row) => new Date(row.created_at).toLocaleDateString(),
	},
];

export default function UsersPage() {
	const { user: currentUser } = useAuth();
	const list = usePagedList(usersApi.list);
	const [teachers, setTeachers] = useState([]);
	const [showForm, setShowForm] = useState(false);
	const [editTarget, setEditTarget] = useState(null);
	const [deleteTarget, setDeleteTarget] = useState(null);

	useEffect(() => {
		teachersApi.list().then(setTeachers).catch(() => {});
	}, []);

	const handleCreate = async (formData) => {
		await usersApi.create(formData);
		list.reload();
	};

	const handleUpdate = async (formData) => {
		await usersApi.update(editTarget.id, formData);
		setEditTarget(null);
		list.reload();
	};

	const handleDelete = async () => {
		if (deleteTarget) {
			await usersApi.delete(deleteTarget.id);
			setDeleteTarget(null);
			list.reload();
		}
	};

	const roleOptions = [
		{ value: "admin", label: "Admin" },
		{ value: "teacher", label: "Teacher" },
		{ value: "parent", label: "Parent" },
	];

	const teacherOptions = [
		{ value: "", label: "None" },
		...teachers.map((t) => ({ value: t.id, label: t.full_name })),
	];

	const createFields = [
		{ name: "email", label: "Email", type: "email", required: true },
		{ name: "role", label: "Role", type: "select", options: roleOptions, defaultValue: "teacher", required: true },
		{ name: "teacher_id", label: "Link to Teacher", type: "select", options: teacherOptions },
		{
			name: "password",
			label: "Password",
			type: "password",
			helperText: "Leave blank to let them set a password with the \"Forgot password\" link.",
		},
	];

	const editFields = editTarget
		? [
			{ name: "role", label: "Role", type: "select", options: roleOptions, defaultValue: editTarget.role, required: true },
			{ name: "teacher_id", label: "Link to Teacher", type: "select", options: teacherOptions, defaultValue: editTarget.teacher_id || "" },
			{
				name: "password",
				label: "New Password",
				type: "password",
				helperText: "Leave blank to keep the current password.",
			},
		]
		: [];

	return (
		<Box>
			<PageHeader
				title="Users"
				onAdd={() => setShowForm(true)}
				addLabel="Add User"
			/>

			<SearchField
				value={list.query}
				onChange={list.setQuery}
				placeholder="Search name, email, role"
				total={list.total}
				noun="users"
			/>
			<DataTable
				columns={columns}
				data={list.rows}
				loading={list.initialLoading}
				onDelete={(row) => (row.id === currentUser?.id ? null : setDeleteTarget(row))}
				onRowClick={(row) => setEditTarget(row)}
				emptyMessage={list.query ? `No users match "${list.query}".` : "No users yet."}
			/>
			<ListPagination list={list} />

			<FormDialog
				open={showForm}
				onClose={() => setShowForm(false)}
				onSubmit={handleCreate}
				title="Add User"
				fields={createFields}
			/>

			{editTarget && (
				<FormDialog
					key={editTarget.id}
					open={!!editTarget}
					onClose={() => setEditTarget(null)}
					onSubmit={handleUpdate}
					title={`Edit ${editTarget.email}`}
					fields={editFields}
					submitLabel="Save"
				/>
			)}

			<ConfirmDialog
				open={!!deleteTarget}
				onClose={() => setDeleteTarget(null)}
				onConfirm={handleDelete}
				title="Delete User"
				message={`Are you sure you want to delete ${deleteTarget?.email}? They will no longer be able to log in.`}
			/>
		</Box>
	);
}
