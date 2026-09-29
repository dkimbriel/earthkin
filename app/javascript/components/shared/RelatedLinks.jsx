import { Box, Chip, Typography } from "@mui/material";
import { useLocation, useNavigate } from "react-router-dom";
import ArrowForwardIcon from "@mui/icons-material/ArrowForward";

// A row of links to the other pages about the same child's enrollment
// (application, enrollment & payments, family). Each link passes where you
// came from, so the destination's Back button returns here.
//
//   <RelatedLinks links={[{ label: "Application", to: "/enrollment-applications/1", icon: <DescriptionIcon /> }]} />
export default function RelatedLinks({ links, note }) {
	const navigate = useNavigate();
	const location = useLocation();
	const from = `${location.pathname}${location.search}`;

	if (links.length === 0 && !note) return null;

	return (
		<Box sx={{ display: "flex", alignItems: "center", gap: 1, flexWrap: "wrap", mt: 1 }}>
			<Typography variant="body2" color="text.secondary">
				Related:
			</Typography>
			{links.map((link) => (
				<Chip
					key={link.to}
					icon={link.icon}
					label={
						<Box component="span" sx={{ display: "inline-flex", alignItems: "center", gap: 0.5 }}>
							{link.label}
							<ArrowForwardIcon sx={{ fontSize: 14 }} />
						</Box>
					}
					variant="outlined"
					size="small"
					clickable
					onClick={() => navigate(link.to, { state: { from } })}
				/>
			))}
			{note && (
				<Typography variant="body2" color="text.secondary" sx={{ fontStyle: "italic" }}>
					{note}
				</Typography>
			)}
		</Box>
	);
}
