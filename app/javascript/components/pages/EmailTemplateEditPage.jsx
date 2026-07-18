import { useState, useEffect, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
	Box,
	Paper,
	Button,
	TextField,
	MenuItem,
	Alert,
	Typography,
	Tooltip,
	Chip,
	Link,
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import TokenEditor from "../shared/TokenEditor";
import { emailTemplatesApi } from "../../utils/api";
import EarthkinLoader from "../shared/EarthkinLoader";

const TEMPLATES_TAB = "/emails?tab=templates";

export default function EmailTemplateEditPage() {
	const { id } = useParams();
	const navigate = useNavigate();
	const isNew = !id;

	const [form, setForm] = useState({ key: "", name: "", subject: "", body: "" });
	const [knownKeys, setKnownKeys] = useState({});
	const [tokenInfo, setTokenInfo] = useState({});
	const [existing, setExisting] = useState(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [busy, setBusy] = useState(false);

	const subjectEditor = useRef(null);
	const bodyEditor = useRef(null);
	const lastFocused = useRef("body");

	useEffect(() => {
		let active = true;
		emailTemplatesApi
			.list()
			.then((data) => {
				if (!active) return;
				setKnownKeys(data.known_keys || {});
				setTokenInfo(data.token_info || {});
				if (!isNew) {
					const tpl = (data.templates || []).find((t) => String(t.id) === String(id));
					if (tpl) {
						setExisting(tpl);
						setForm({ key: tpl.key || "", name: tpl.name || "", subject: tpl.subject || "", body: tpl.body || "" });
					} else {
						setError("Template not found.");
					}
				}
			})
			.catch((err) => active && setError(err.message))
			.finally(() => active && setLoading(false));
		return () => {
			active = false;
		};
	}, [id, isNew]);

	const set = (name, value) => setForm((prev) => ({ ...prev, [name]: value }));
	const tokens = form.key ? knownKeys[form.key] || [] : [];

	const insertToken = (token) => {
		const editor = lastFocused.current === "subject" ? subjectEditor : bodyEditor;
		editor.current?.insertToken(token);
	};

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setBusy(true);
		try {
			if (existing?.id) {
				await emailTemplatesApi.update(existing.id, form);
			} else {
				await emailTemplatesApi.create(form);
			}
			navigate(TEMPLATES_TAB);
		} catch (err) {
			setError(err.message);
		} finally {
			setBusy(false);
		}
	};

	if (loading) return <EarthkinLoader />;

	return (
		<Box>
			<Button startIcon={<ArrowBackIcon />} onClick={() => navigate(TEMPLATES_TAB)} sx={{ mb: 2 }}>
				Back to Templates
			</Button>
			<Paper sx={{ p: 3, maxWidth: 900 }}>
				<form onSubmit={handleSubmit}>
					<Typography variant="h5" gutterBottom>
						{existing ? `Edit ${existing.name}` : "New Template"}
					</Typography>
					{error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
					<Box sx={{ display: "flex", flexDirection: "column", gap: 2, mt: 1 }}>
						<TextField
							select
							label="Workflow email"
							value={form.key}
							onChange={(e) => set("key", e.target.value)}
							fullWidth
							disabled={!!existing?.key}
							helperText={
								existing?.key
									? "This template is the wording used for this workflow email."
									: "Pick a workflow email to edit its wording, or leave as 'None' for a reusable manual-email template."
							}
						>
							<MenuItem value="">None (manual email template)</MenuItem>
							{Object.keys(knownKeys).map((k) => (
								<MenuItem key={k} value={k}>{k.replace(/_/g, " ")}</MenuItem>
							))}
						</TextField>
						<TextField
							label="Template Name"
							value={form.name}
							onChange={(e) => set("name", e.target.value)}
							required
							fullWidth
						/>
						{form.key ? (
							<>
								<TokenEditor
									ref={subjectEditor}
									label="Subject"
									value={form.subject}
									onChange={(v) => set("subject", v)}
									onFocus={() => (lastFocused.current = "subject")}
								/>
								<TokenEditor
									ref={bodyEditor}
									label="Body"
									value={form.body}
									onChange={(v) => set("body", v)}
									onFocus={() => (lastFocused.current = "body")}
									multiline
									minRows={16}
								/>
							</>
						) : (
							<>
								<TextField
									label="Subject"
									value={form.subject}
									onChange={(e) => set("subject", e.target.value)}
									required
									fullWidth
								/>
								<TextField
									label="Body"
									value={form.body}
									onChange={(e) => set("body", e.target.value)}
									multiline
									rows={16}
									required
									fullWidth
								/>
							</>
						)}
						{tokens.length > 0 && (
							<Box>
								<Typography variant="caption" color="text.secondary">
									Tokens fill in automatically when the email is sent. Click one to insert it at your cursor; hover to see where its value comes from.{" "}
									<Link href="/help#email-tokens" target="_blank" rel="noopener">Full token guide</Link>
								</Typography>
								<Box sx={{ display: "flex", gap: 1, flexWrap: "wrap", mt: 0.5, mb: 1 }}>
									{tokens.map((t) => (
										<Tooltip key={t} title={tokenInfo?.[t] || ""} arrow>
											<Chip
												size="small"
												label={t.replace(/_/g, " ")}
												onClick={() => insertToken(t)}
												clickable
												color="success"
												variant="outlined"
											/>
										</Tooltip>
									))}
								</Box>
								<Box component="dl" sx={{ m: 0 }}>
									{tokens.map((t) => (
										<Typography key={t} variant="caption" color="text.secondary" component="div" sx={{ mb: 0.25 }}>
											<strong>{`{{${t}}}`}</strong> — {tokenInfo?.[t] || ""}
										</Typography>
									))}
								</Box>
							</Box>
						)}
						<Box sx={{ display: "flex", gap: 2, justifyContent: "flex-end", mt: 1 }}>
							<Button onClick={() => navigate(TEMPLATES_TAB)}>Cancel</Button>
							<Button type="submit" variant="contained" disabled={busy}>
								{busy ? "Saving..." : "Save"}
							</Button>
						</Box>
					</Box>
				</form>
			</Paper>
		</Box>
	);
}
