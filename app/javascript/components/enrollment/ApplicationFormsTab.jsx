import { useState, useEffect } from "react";
import {
	Box,
	Typography,
	Button,
	Chip,
	Alert,
	Paper,
	Dialog,
	DialogTitle,
	DialogContent,
	DialogActions,
	Divider,
} from "@mui/material";
import DescriptionIcon from "@mui/icons-material/Description";
import DownloadIcon from "@mui/icons-material/Download";
import { formSignaturesApi } from "../../utils/api";
import EarthkinLoader from "../shared/EarthkinLoader";

// The "Enrollment Forms" tab on an application: shows the e-sign forms for the
// application's child, their signing status, and lets an admin issue them.
export default function ApplicationFormsTab({ application, isAdmin, onChanged }) {
	const child = application.child;
	const [signatures, setSignatures] = useState([]);
	const [loading, setLoading] = useState(false);
	const [error, setError] = useState(null);
	const [issuing, setIssuing] = useState(false);
	const [viewTarget, setViewTarget] = useState(null);

	const load = async () => {
		if (!child?.id) return;
		setLoading(true);
		try {
			setSignatures(await formSignaturesApi.listByChild(child.id));
		} catch (err) {
			setError(err.message);
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		load();
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [child?.id]);

	const handleIssue = async () => {
		setIssuing(true);
		setError(null);
		try {
			await formSignaturesApi.issueForChild(child.id);
			await load();
			onChanged?.();
		} catch (err) {
			setError(err.message);
		} finally {
			setIssuing(false);
		}
	};

	// No child record yet — forms are created once the fee is recorded.
	if (!child?.id) {
		return (
			<Alert severity="info" icon={<DescriptionIcon />}>
				Enrollment forms appear here once the family pays the enrollment fee and the
				child record is created. Record the fee to get started.
			</Alert>
		);
	}

	if (loading) return <EarthkinLoader minHeight={160} />;

	const signedCount = signatures.filter((s) => s.status === "signed").length;

	return (
		<Box>
			{error && (
				<Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
					{error}
				</Alert>
			)}

			<Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 2 }}>
				<Typography variant="h6">
					Enrollment Forms for {child.first_name} {child.last_name}
					{signatures.length > 0 && (
						<Typography component="span" color="text.secondary" sx={{ ml: 1 }}>
							({signedCount}/{signatures.length} signed)
						</Typography>
					)}
				</Typography>
				{isAdmin && signatures.length === 0 && (
					<Button variant="outlined" onClick={handleIssue} disabled={issuing}>
						{issuing ? "Issuing…" : "Issue Enrollment Forms"}
					</Button>
				)}
			</Box>

			{signatures.length === 0 ? (
				<Typography color="text.secondary">
					No forms issued yet. Issue enrollment forms to send them to the family's portal for signing.
				</Typography>
			) : (
				<Paper variant="outlined">
					{signatures.map((sig, i) => (
						<Box key={sig.id}>
							{i > 0 && <Divider />}
							<Box sx={{ display: "flex", alignItems: "center", gap: 2, p: 2, flexWrap: "wrap" }}>
								<Box sx={{ flexGrow: 1, minWidth: 0 }}>
									<Typography fontWeight="medium">{sig.form_name}</Typography>
									<Typography variant="body2" color="text.secondary">
										{sig.status === "signed"
											? `Signed by ${sig.signed_by_name}${sig.signed_by_email ? ` (${sig.signed_by_email})` : ""} on ${new Date(sig.signed_at).toLocaleString()}`
											: "Awaiting the family's signature"}
									</Typography>
								</Box>
								<Chip
									label={sig.status === "signed" ? "Signed" : "Pending"}
									color={sig.status === "signed" ? "success" : "warning"}
									variant={sig.status === "signed" ? "filled" : "outlined"}
									size="small"
								/>
								<Button size="small" onClick={() => setViewTarget(sig)}>
									View
								</Button>
								{sig.status === "signed" && (
									<Button
										size="small"
										startIcon={<DownloadIcon />}
										component="a"
										href={formSignaturesApi.pdfPath(sig.id)}
										target="_blank"
										rel="noopener"
									>
										PDF
									</Button>
								)}
							</Box>
						</Box>
					))}
				</Paper>
			)}

			{viewTarget && (
				<Dialog open onClose={() => setViewTarget(null)} maxWidth="md" fullWidth>
					<DialogTitle>
						{viewTarget.form_name} — {viewTarget.child_name}
					</DialogTitle>
					<DialogContent dividers>
						<Chip
							label={viewTarget.status === "signed" ? "Signed" : "Pending"}
							color={viewTarget.status === "signed" ? "success" : "warning"}
							size="small"
							sx={{ mb: 2 }}
						/>
						{viewTarget.status === "signed" && (
							<Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
								Signed by {viewTarget.signed_by_name}
								{viewTarget.signed_by_email ? ` (${viewTarget.signed_by_email})` : ""} on{" "}
								{new Date(viewTarget.signed_at).toLocaleString()}
							</Typography>
						)}
						{viewTarget.audit_log?.length > 0 && (
							<Box sx={{ mb: 2 }}>
								<Typography variant="subtitle2">Audit trail</Typography>
								{viewTarget.audit_log.map((entry, i) => (
									<Typography key={i} variant="caption" component="div" color="text.secondary">
										{entry.event}
										{entry.by ? ` — ${entry.by}` : ""}
										{entry.at ? ` — ${new Date(entry.at).toLocaleString()}` : ""}
									</Typography>
								))}
							</Box>
						)}
						<Divider sx={{ mb: 2 }} />
						<Typography
							variant="body2"
							sx={{ whiteSpace: "pre-wrap", fontFamily: "inherit" }}
						>
							{viewTarget.form_body_snapshot || "This form hasn't been signed yet, so there's no signed copy to show."}
						</Typography>
					</DialogContent>
					<DialogActions>
						{viewTarget.status === "signed" && (
							<Button
								startIcon={<DownloadIcon />}
								component="a"
								href={formSignaturesApi.pdfPath(viewTarget.id)}
								target="_blank"
								rel="noopener"
							>
								Download PDF
							</Button>
						)}
						<Button onClick={() => setViewTarget(null)}>Close</Button>
					</DialogActions>
				</Dialog>
			)}
		</Box>
	);
}
