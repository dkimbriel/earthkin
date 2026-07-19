import { useState, useEffect } from "react";
import { Box, Typography, Button, Chip, Alert, Snackbar } from "@mui/material";
import RestoreIcon from "@mui/icons-material/Restore";
import DataTable from "../shared/DataTable";
import ConfirmDialog from "../shared/ConfirmDialog";
import { deletedRecordsApi } from "../../utils/api";

export default function RecentlyDeletedPage() {
	const [records, setRecords] = useState([]);
	const [loading, setLoading] = useState(true);
	const [restoreTarget, setRestoreTarget] = useState(null);
	const [error, setError] = useState(null);
	const [notice, setNotice] = useState(null);

	const load = async () => {
		setLoading(true);
		try {
			setRecords(await deletedRecordsApi.list());
		} catch (err) {
			setError(err.message);
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		load();
	}, []);

	const handleRestore = async () => {
		const target = restoreTarget;
		setRestoreTarget(null);
		try {
			const result = await deletedRecordsApi.restore(target.type, target.id);
			setNotice(result.message || "Restored");
			load();
		} catch (err) {
			setError(err.message);
		}
	};

	const columns = [
		{
			key: "type_label",
			label: "Type",
			render: (row) => <Chip size="small" label={row.type_label} />,
		},
		{ key: "label", label: "Item" },
		{
			key: "deleted_at",
			label: "Deleted",
			render: (row) => new Date(row.deleted_at).toLocaleString(),
		},
		{
			key: "actions",
			label: "",
			render: (row) => (
				<Button
					size="small"
					startIcon={<RestoreIcon />}
					onClick={() => setRestoreTarget(row)}
				>
					Restore
				</Button>
			),
		},
	];

	return (
		<Box>
			<Typography variant="h5" component="h1" gutterBottom>
				Recently Deleted
			</Typography>
			<Typography color="text.secondary" sx={{ mb: 2 }}>
				Deleted records are kept here so you can restore them. Restoring an item also
				brings back the records that were removed with it (for example, a family's
				children and parents).
			</Typography>

			{error && (
				<Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
					{error}
				</Alert>
			)}

			<DataTable
				columns={columns}
				data={records}
				loading={loading}
				emptyMessage="Nothing has been deleted recently."
			/>

			<ConfirmDialog
				open={!!restoreTarget}
				onClose={() => setRestoreTarget(null)}
				onConfirm={handleRestore}
				title="Restore item"
				message={`Restore "${restoreTarget?.label}"? Any records deleted along with it will be restored too.`}
				confirmLabel="Restore"
				confirmColor="primary"
			/>

			<Snackbar
				open={!!notice}
				autoHideDuration={5000}
				onClose={() => setNotice(null)}
				anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
			>
				<Alert severity="success" onClose={() => setNotice(null)} sx={{ width: "100%" }}>
					{notice}
				</Alert>
			</Snackbar>
		</Box>
	);
}
