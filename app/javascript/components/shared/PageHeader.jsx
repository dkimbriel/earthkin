import { Box, Typography, Button } from "@mui/material";
import AddIcon from "@mui/icons-material/Add";

export default function PageHeader({ title, onAdd, addLabel = "Add New" }) {
	return (
		<Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 3 }}>
			<Typography variant="h5" component="h1">
				{title}
			</Typography>
			{onAdd && (
				<Button variant="contained" startIcon={<AddIcon />} onClick={onAdd}>
					{addLabel}
				</Button>
			)}
		</Box>
	);
}
