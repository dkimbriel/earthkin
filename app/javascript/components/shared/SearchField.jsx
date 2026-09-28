import { Box, TextField, InputAdornment, IconButton, Typography } from "@mui/material";
import SearchIcon from "@mui/icons-material/Search";
import ClearIcon from "@mui/icons-material/Clear";

// Search box for a list page, usually wired to usePagedList. While a query is
// active it shows how many records matched, e.g. "12 matching families".
export default function SearchField({ value, onChange, placeholder = "Search", total, noun = "results" }) {
	return (
		<Box sx={{ mb: 2 }}>
			<TextField
				value={value}
				onChange={(e) => onChange(e.target.value)}
				onKeyDown={(e) => e.key === "Escape" && onChange("")}
				placeholder={placeholder}
				size="small"
				inputProps={{ "aria-label": placeholder }}
				sx={{ width: { xs: "100%", sm: 320 } }}
				InputProps={{
					startAdornment: (
						<InputAdornment position="start">
							<SearchIcon fontSize="small" />
						</InputAdornment>
					),
					endAdornment: value ? (
						<InputAdornment position="end">
							<IconButton size="small" aria-label="Clear search" onClick={() => onChange("")} edge="end">
								<ClearIcon fontSize="small" />
							</IconButton>
						</InputAdornment>
					) : null,
				}}
			/>
			{value && total != null && (
				<Typography variant="caption" color="text.secondary" sx={{ display: "block", mt: 0.5 }}>
					{total} matching {noun}
				</Typography>
			)}
		</Box>
	);
}
