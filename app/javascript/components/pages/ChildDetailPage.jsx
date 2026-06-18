import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { Box, Typography, Button, Paper, Chip } from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import DataTable from "../shared/DataTable";
import { childrenApi } from "../../utils/api";

const enrollmentColumns = [
	{
		key: "program",
		label: "Program",
		render: (row) => row.program?.name,
	},
	{
		key: "status",
		label: "Status",
		render: (row) => (
			<Chip
				label={row.status}
				color={row.status === "confirmed" ? "success" : row.status === "cancelled" ? "error" : "default"}
				size="small"
			/>
		),
	},
	{
		key: "rate_per_class",
		label: "Rate/Class",
		render: (row) => `$${parseFloat(row.rate_per_class).toFixed(2)}`,
	},
];

export default function ChildDetailPage() {
	const { id } = useParams();
	const navigate = useNavigate();
	const [child, setChild] = useState(null);
	const [loading, setLoading] = useState(true);

	useEffect(() => {
		const loadChild = async () => {
			setLoading(true);
			try {
				const data = await childrenApi.get(id);
				setChild(data);
			} finally {
				setLoading(false);
			}
		};
		loadChild();
	}, [id]);

	if (loading) {
		return <Typography>Loading...</Typography>;
	}

	if (!child) {
		return <Typography>Child not found</Typography>;
	}

	return (
		<Box>
			<Button
				startIcon={<ArrowBackIcon />}
				onClick={() => navigate(`/families/${child.family?.id}`)}
				sx={{ mb: 2 }}
			>
				Back to Family
			</Button>

			<Typography variant="h4" gutterBottom>
				{child.first_name} {child.last_name}
			</Typography>

			<Box sx={{ mb: 3 }}>
				<Typography color="text.secondary">Family: {child.family?.name}</Typography>
			</Box>

			<Paper sx={{ p: 3 }}>
				<Typography variant="h6" gutterBottom>
					Program Enrollments
				</Typography>
				<DataTable
					columns={enrollmentColumns}
					data={child.program_enrollments}
					loading={false}
					onRowClick={(row) => navigate(`/enrollments/${row.id}`)}
					emptyMessage="Not enrolled in any programs."
				/>
			</Paper>
		</Box>
	);
}
