import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Box } from "@mui/material";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import SearchField from "../shared/SearchField";
import ListPagination from "../shared/ListPagination";
import { familiesApi } from "../../utils/api";
import usePagedList from "../../utils/usePagedList";
import { useAuth } from "../../contexts/AuthContext";

const columns = [
	{ key: "name", label: "Family Name" },
	{
		key: "parents",
		label: "Parents",
		render: (row) => row.parents?.map((p) => `${p.first_name} ${p.last_name}`).join(", ") || "—",
	},
	{
		key: "children",
		label: "Children",
		render: (row) => row.children?.map((c) => `${c.first_name} ${c.last_name}`).join(", ") || "—",
	},
];

const formFields = [{ name: "name", label: "Family Name", required: true }];

export default function FamiliesPage() {
	const { user } = useAuth();
	const isAdmin = user?.role === "admin";
	const navigate = useNavigate();
	const [showForm, setShowForm] = useState(false);
	const [deleteTarget, setDeleteTarget] = useState(null);
	const list = usePagedList(familiesApi.list);

	const handleCreate = async (formData) => {
		await familiesApi.create(formData);
		list.reload();
	};

	const handleDelete = async () => {
		if (deleteTarget) {
			await familiesApi.delete(deleteTarget.id);
			setDeleteTarget(null);
			list.reload();
		}
	};

	return (
		<Box>
			<PageHeader title="Families" onAdd={isAdmin ? () => setShowForm(true) : undefined} addLabel="Add Family" />
			<SearchField
				value={list.query}
				onChange={list.setQuery}
				placeholder="Search families, parents, children"
				total={list.total}
				noun="families"
			/>
			<DataTable
				columns={columns}
				data={list.rows}
				loading={list.initialLoading}
				onDelete={isAdmin ? setDeleteTarget : undefined}
				onRowClick={(row) => navigate(`/families/${row.id}`)}
				emptyMessage={list.query ? `No families match "${list.query}".` : "No families yet. Add one to get started."}
			/>
			<ListPagination list={list} />
			<FormDialog
				open={showForm}
				onClose={() => setShowForm(false)}
				onSubmit={handleCreate}
				title="Add Family"
				fields={formFields}
			/>
			<ConfirmDialog
				open={!!deleteTarget}
				onClose={() => setDeleteTarget(null)}
				onConfirm={handleDelete}
				title="Delete Family"
				message={`Are you sure you want to delete "${deleteTarget?.name}"? This will also delete all associated parents and children.`}
			/>
		</Box>
	);
}
