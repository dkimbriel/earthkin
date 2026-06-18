import {
	Table,
	TableBody,
	TableCell,
	TableContainer,
	TableHead,
	TableRow,
	Paper,
	IconButton,
	Typography,
	Box,
	CircularProgress,
} from "@mui/material";
import DeleteIcon from "@mui/icons-material/Delete";

export default function DataTable({
	columns,
	data,
	loading,
	onDelete,
	canDelete,
	onRowClick,
	canRowClick,
	emptyMessage = "No data available",
}) {
	if (loading) {
		return (
			<Box sx={{ display: "flex", justifyContent: "center", p: 4 }}>
				<CircularProgress />
			</Box>
		);
	}

	if (!data || data.length === 0) {
		return (
			<Box sx={{ textAlign: "center", p: 4 }}>
				<Typography color="text.secondary">{emptyMessage}</Typography>
			</Box>
		);
	}

	return (
		<TableContainer component={Paper} variant="outlined">
			<Table>
				<TableHead>
					<TableRow>
						{columns.map((column) => (
							<TableCell key={column.key} sx={{ fontWeight: "bold" }}>
								{column.label}
							</TableCell>
						))}
						{onDelete && <TableCell sx={{ width: 60 }} />}
					</TableRow>
				</TableHead>
				<TableBody>
					{data.map((row) => {
						const isClickable = onRowClick && (!canRowClick || canRowClick(row));
						return (
						<TableRow
							key={row.id}
							hover={isClickable}
							onClick={() => isClickable && onRowClick(row)}
							sx={{ cursor: isClickable ? "pointer" : "default" }}
						>
							{columns.map((column) => (
								<TableCell key={column.key}>
									{column.render ? column.render(row) : row[column.key]}
								</TableCell>
							))}
							{onDelete && (
								<TableCell>
									{(!canDelete || canDelete(row)) && (
										<IconButton
											size="small"
											onClick={(e) => {
												e.stopPropagation();
												onDelete(row);
											}}
											color="error"
										>
											<DeleteIcon fontSize="small" />
										</IconButton>
									)}
								</TableCell>
							)}
						</TableRow>
					);
					})}
				</TableBody>
			</Table>
		</TableContainer>
	);
}
