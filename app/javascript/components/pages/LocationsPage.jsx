import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Box } from "@mui/material";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import SearchField from "../shared/SearchField";
import ListPagination from "../shared/ListPagination";
import { locationsApi } from "../../utils/api";
import usePagedList from "../../utils/usePagedList";

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
	const list = usePagedList(locationsApi.list);
	const [showForm, setShowForm] = useState(false);
	const [deleteTarget, setDeleteTarget] = useState(null);

	const handleCreate = async (formData) => {
		await locationsApi.create(formData);
		list.reload();
	};

	const handleDelete = async () => {
		if (deleteTarget) {
			await locationsApi.delete(deleteTarget.id);
			setDeleteTarget(null);
			list.reload();
		}
	};

	return (
		<Box>
			<PageHeader title="Locations" onAdd={() => setShowForm(true)} addLabel="Add Location" />
			<SearchField
				value={list.query}
				onChange={list.setQuery}
				placeholder="Search name, address, notes"
				total={list.total}
				noun="locations"
			/>
			<DataTable
				columns={columns}
				data={list.rows}
				loading={list.initialLoading}
				onDelete={setDeleteTarget}
				onRowClick={(row) => navigate(`/locations/${row.id}/edit`)}
				emptyMessage={list.query ? `No locations match "${list.query}".` : "No locations yet. Add one to get started."}
			/>
			<ListPagination list={list} />
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
