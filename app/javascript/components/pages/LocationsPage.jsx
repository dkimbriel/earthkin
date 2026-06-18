import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Box } from "@mui/material";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import { locationsApi } from "../../utils/api";

const columns = [
	{ key: "name", label: "Name" },
	{ key: "address", label: "Address", render: (row) => row.address || "—" },
	{ key: "notes", label: "Notes", render: (row) => row.notes || "—" },
];

const formFields = [
	{ name: "name", label: "Location Name", required: true },
	{ name: "address", label: "Address", multiline: true, rows: 2 },
	{ name: "notes", label: "Notes", multiline: true, rows: 2 },
];

export default function LocationsPage() {
	const navigate = useNavigate();
	const [locations, setLocations] = useState([]);
	const [loading, setLoading] = useState(true);
	const [showForm, setShowForm] = useState(false);
	const [deleteTarget, setDeleteTarget] = useState(null);

	const loadLocations = async () => {
		setLoading(true);
		try {
			const data = await locationsApi.list();
			setLocations(data);
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		loadLocations();
	}, []);

	const handleCreate = async (formData) => {
		await locationsApi.create(formData);
		loadLocations();
	};

	const handleDelete = async () => {
		if (deleteTarget) {
			await locationsApi.delete(deleteTarget.id);
			setDeleteTarget(null);
			loadLocations();
		}
	};

	return (
		<Box>
			<PageHeader title="Locations" onAdd={() => setShowForm(true)} addLabel="Add Location" />
			<DataTable
				columns={columns}
				data={locations}
				loading={loading}
				onDelete={setDeleteTarget}
				onRowClick={(row) => navigate(`/locations/${row.id}/edit`)}
				emptyMessage="No locations yet. Add one to get started."
			/>
			<FormDialog
				open={showForm}
				onClose={() => setShowForm(false)}
				onSubmit={handleCreate}
				title="Add Location"
				fields={formFields}
			/>
			<ConfirmDialog
				open={!!deleteTarget}
				onClose={() => setDeleteTarget(null)}
				onConfirm={handleDelete}
				title="Delete Location"
				message={`Are you sure you want to delete "${deleteTarget?.name}"?`}
			/>
		</Box>
	);
}
