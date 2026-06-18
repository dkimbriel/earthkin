import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Box } from "@mui/material";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import { familiesApi } from "../../utils/api";

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
	const navigate = useNavigate();
	const [families, setFamilies] = useState([]);
	const [loading, setLoading] = useState(true);
	const [showForm, setShowForm] = useState(false);
	const [deleteTarget, setDeleteTarget] = useState(null);

	const loadFamilies = async () => {
		setLoading(true);
		try {
			const data = await familiesApi.list();
			setFamilies(data);
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		loadFamilies();
	}, []);

	const handleCreate = async (formData) => {
		await familiesApi.create(formData);
		loadFamilies();
	};

	const handleDelete = async () => {
		if (deleteTarget) {
			await familiesApi.delete(deleteTarget.id);
			setDeleteTarget(null);
			loadFamilies();
		}
	};

	return (
		<Box>
			<PageHeader title="Families" onAdd={() => setShowForm(true)} addLabel="Add Family" />
			<DataTable
				columns={columns}
				data={families}
				loading={loading}
				onDelete={setDeleteTarget}
				onRowClick={(row) => navigate(`/families/${row.id}`)}
				emptyMessage="No families yet. Add one to get started."
			/>
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
