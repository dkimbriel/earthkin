import { Box, Typography, Button } from "@mui/material";
import AddIcon from "@mui/icons-material/Add";

export default function PageHeader({ title, onAdd, addLabel = "Add New", actions }) {
	return (
		<Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 3 }}>
			<Typography variant="h5" component="h1">
				{title}
			</Typography>
			{(actions || onAdd) && (
				<Box sx={{ display: "flex", gap: 1 }}>
					{actions}
					{onAdd && (
						<Button variant="contained" startIcon={<AddIcon />} onClick={onAdd}>
							{addLabel}
						</Button>
					)}
				</Box>
			)}
		</Box>
	);
}
