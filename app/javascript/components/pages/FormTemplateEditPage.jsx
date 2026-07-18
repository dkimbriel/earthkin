import { useState, useEffect, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
	Box,
	Paper,
	Button,
	TextField,
	Alert,
	Typography,
	Tooltip,
	Chip,
	Link,
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import TokenEditor from "../shared/TokenEditor";
import { formTemplatesApi } from "../../utils/api";

const FORMS_TAB = "/emails?tab=forms";

const FIELD_HELP =
	"Formatting: # / ## / ### headings, **bold**, - bullets. Fill-in fields the parent completes: [[text:key|Label]] (end the label with * to make it required), [[textarea:key|Label]], [[checkbox:key|Label]], [[require-one:key1,key2|Message]] for a required choice, [[waive-required-if:key]] to waive all requirements when a checkbox is checked, [[payment-plans]] to list all payment plans, [[tuition-plan]] to show just this child's tuition and due dates, and [[signature]] where the parent signs.";

export default function FormTemplateEditPage() {
	const { id } = useParams();
	const navigate = useNavigate();

	const [form, setForm] = useState({ name: "", body: "" });
	const [tokens, setTokens] = useState([]);
	const [tokenInfo, setTokenInfo] = useState({});
	const [existing, setExisting] = useState(null);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [busy, setBusy] = useState(false);

	const bodyEditor = useRef(null);

	useEffect(() => {
		let active = true;
		formTemplatesApi
			.list()
			.then((data) => {
				if (!active) return;
				setTokens(data.known_tokens || []);
				setTokenInfo(data.token_info || {});
				const tpl = (data.forms || []).find((t) => String(t.id) === String(id));
				if (tpl) {
					setExisting(tpl);
					setForm({ name: tpl.name || "", body: tpl.body || "" });
				} else {
					setError("Form not found.");
				}
			})
			.catch((err) => active && setError(err.message))
			.finally(() => active && setLoading(false));
		return () => {
			active = false;
		};
	}, [id]);

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setBusy(true);
		try {
			await formTemplatesApi.update(existing.id, form);
			navigate(FORMS_TAB);
		} catch (err) {
			setError(err.message);
		} finally {
			setBusy(false);
		}
	};

	if (loading) return <Typography>Loading...</Typography>;

	return (
		<Box>
			<Button startIcon={<ArrowBackIcon />} onClick={() => navigate(FORMS_TAB)} sx={{ mb: 2 }}>
				Back to Enrollment Forms
			</Button>
			<Paper sx={{ p: 3, maxWidth: 900 }}>
				<form onSubmit={handleSubmit}>
					<Typography variant="h5" gutterBottom>
						Edit {existing?.name}
					</Typography>
					{error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
					<Box sx={{ display: "flex", flexDirection: "column", gap: 2, mt: 1 }}>
						<TextField
							label="Form Name"
							value={form.name}
							onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))}
							required
							fullWidth
						/>
						<TokenEditor
							ref={bodyEditor}
							label="Form Text (what parents read and sign)"
							value={form.body}
							onChange={(v) => setForm((p) => ({ ...p, body: v }))}
							multiline
							minRows={18}
						/>
						{tokens.length > 0 && (
							<Box>
								<Typography variant="caption" color="text.secondary">
									Tokens fill in with the family's details when the parent opens the form. Click one to insert it at your cursor; hover to see where its value comes from.{" "}
									<Link href="/help#form-tokens" target="_blank" rel="noopener">Full form guide</Link>
								</Typography>
								<Box sx={{ display: "flex", gap: 1, flexWrap: "wrap", mt: 0.5, mb: 1 }}>
									{tokens.map((t) => (
										<Tooltip key={t} title={tokenInfo?.[t] || ""} arrow>
											<Chip
												size="small"
												label={t.replace(/_/g, " ")}
												onClick={() => bodyEditor.current?.insertToken(t)}
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
						<Alert severity="info" sx={{ "& .MuiAlert-message": { fontSize: "0.8rem" } }}>
							{FIELD_HELP}
						</Alert>
						<Box sx={{ display: "flex", gap: 2, justifyContent: "flex-end", mt: 1 }}>
							<Button onClick={() => navigate(FORMS_TAB)}>Cancel</Button>
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
