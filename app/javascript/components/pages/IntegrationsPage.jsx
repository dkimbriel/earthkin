import { useState, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import {
	Box,
	Card,
	CardContent,
	Typography,
	Button,
	Chip,
	Alert,
	Stack,
	Divider,
} from "@mui/material";
import EmailIcon from "@mui/icons-material/Email";
import CheckCircleIcon from "@mui/icons-material/CheckCircle";
import PageHeader from "../shared/PageHeader";
import ConfirmDialog from "../shared/ConfirmDialog";
import { integrationsApi } from "../../utils/api";
import EarthkinLoader from "../shared/EarthkinLoader";

const RETURN_MESSAGES = {
	connected: { severity: "success", text: "Gmail connected successfully." },
	error: { severity: "error", text: "Couldn't connect Gmail. Please try again." },
	missing_scope: {
		severity: "error",
		text: "Google connected, but the \"Send email on your behalf\" permission wasn't granted, so nothing was saved. Click Connect again and make sure that checkbox is CHECKED on the Google screen.",
	},
	not_configured: {
		severity: "warning",
		text: "Google OAuth credentials aren't configured on the server yet.",
	},
};

export default function IntegrationsPage() {
	const [status, setStatus] = useState(null);
	const [loading, setLoading] = useState(true);
	const [disconnecting, setDisconnecting] = useState(false);
	const [confirmOpen, setConfirmOpen] = useState(false);
	const [searchParams, setSearchParams] = useSearchParams();

	const returnMessage = RETURN_MESSAGES[searchParams.get("gmail")];

	const loadStatus = async () => {
		setLoading(true);
		try {
			setStatus(await integrationsApi.gmailStatus());
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		loadStatus();
		// Clear the ?gmail= param so the banner doesn't persist on refresh.
		if (searchParams.has("gmail")) {
			const next = new URLSearchParams(searchParams);
			next.delete("gmail");
			setSearchParams(next, { replace: true });
		}
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, []);

	const handleConnect = () => {
		window.location.href = integrationsApi.gmailConnectUrl;
	};

	const handleDisconnect = async () => {
		setDisconnecting(true);
		try {
			setStatus(await integrationsApi.disconnectGmail());
			setConfirmOpen(false);
		} finally {
			setDisconnecting(false);
		}
	};

	if (loading) {
		return (
			<Box sx={{ display: "flex", justifyContent: "center", mt: 6 }}>
				<EarthkinLoader />
			</Box>
		);
	}

	const connected = status?.connected;
	const expired = connected && status?.healthy === false;

	return (
		<Box>
			<PageHeader title="Integrations" />

			{returnMessage && (
				<Alert severity={returnMessage.severity} sx={{ mb: 3 }}>
					{returnMessage.text}
				</Alert>
			)}

			<Card variant="outlined" sx={{ maxWidth: 640 }}>
				<CardContent>
					<Stack direction="row" spacing={2} alignItems="center" sx={{ mb: 1 }}>
						<EmailIcon color="action" />
						<Box sx={{ flexGrow: 1 }}>
							<Typography variant="h6">Gmail</Typography>
							<Typography variant="body2" color="text.secondary">
								Send the school's outgoing emails from a connected Gmail mailbox.
							</Typography>
						</Box>
						<Chip
							size="small"
							color={expired ? "error" : connected ? "success" : "default"}
							icon={connected && !expired ? <CheckCircleIcon /> : undefined}
							label={expired ? "Connection expired" : connected ? "Connected" : "Not connected"}
						/>
					</Stack>

					<Divider sx={{ my: 2 }} />

					{connected ? (
						<>
							{expired && (
								<Alert severity="error" sx={{ mb: 2 }}>
									{status?.send_scope_missing
										? 'This connection is missing the "Send email on your behalf" permission, so outgoing emails are failing. Click Reconnect and make sure that checkbox is CHECKED on the Google consent screen.'
										: 'Google has revoked this connection, so outgoing emails are failing. Click Reconnect and sign in with the school account to resume sending. (While the Google OAuth app is in "Testing" status, this happens every 7 days — publish the app in Google Cloud Console to make it permanent.)'}
								</Alert>
							)}
							<Typography variant="body2" sx={{ mb: 0.5 }}>
								<strong>Account:</strong> {status.email || "—"}
							</Typography>
							{status.connected_by && (
								<Typography variant="body2" color="text.secondary">
									Connected by {status.connected_by}
								</Typography>
							)}
							<Stack direction="row" spacing={1} sx={{ mt: 2 }}>
								{expired && (
									<Button variant="contained" onClick={handleConnect}>
										Reconnect Gmail
									</Button>
								)}
								<Button
									color="error"
									variant="outlined"
									onClick={() => setConfirmOpen(true)}
								>
									Disconnect
								</Button>
							</Stack>
						</>
					) : (
						<>
							{status?.configured === false && (
								<Alert severity="warning" sx={{ mb: 2 }}>
									Google OAuth credentials aren't configured on the server. Set
									GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET first.
								</Alert>
							)}
							<Button
								variant="contained"
								onClick={handleConnect}
								disabled={status?.configured === false}
							>
								Connect Gmail
							</Button>
						</>
					)}
				</CardContent>
			</Card>

			<ConfirmDialog
				open={confirmOpen}
				title="Disconnect Gmail?"
				message="Outgoing emails will stop sending until a mailbox is reconnected."
				confirmLabel={disconnecting ? "Disconnecting…" : "Disconnect"}
				onConfirm={handleDisconnect}
				onClose={() => setConfirmOpen(false)}
			/>
		</Box>
	);
}
