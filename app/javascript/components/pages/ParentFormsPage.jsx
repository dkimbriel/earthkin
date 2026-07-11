import { useState, useEffect } from "react";
import {
    Box,
    Typography,
    Card,
    CardContent,
    Chip,
    Alert,
    CircularProgress,
    Stack,
    Button,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    FormControlLabel,
    Checkbox,
    Paper,
} from "@mui/material";
import { portalApi } from "../../utils/api";

// The signature preview and signed record render the typed name in cursive.
const SIGNATURE_FONT = '"Snell Roundhand", "Savoye LET", "Brush Script MT", "Segoe Script", cursive';

function SignDialog({ form, onClose, onSigned }) {
    const [name, setName] = useState("");
    const [answers, setAnswers] = useState("");
    const [agreed, setAgreed] = useState(false);
    const [error, setError] = useState(null);
    const [busy, setBusy] = useState(false);

    // Opening the form is part of the signing audit trail.
    useEffect(() => {
        portalApi.viewForm(form.id).catch(() => {});
    }, [form.id]);

    const asksForAnswers = (form.form_body || "").includes("Your answers");

    const handleSign = async () => {
        setError(null);
        setBusy(true);
        try {
            await portalApi.signForm(form.id, name, answers);
            onSigned();
            onClose();
        } catch (err) {
            setError(err.message);
        } finally {
            setBusy(false);
        }
    };

    return (
        <Dialog open onClose={onClose} maxWidth="md" fullWidth>
            <DialogTitle>
                {form.form_name} — {form.child_name}
            </DialogTitle>
            <DialogContent>
                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                <Paper
                    variant="outlined"
                    sx={{ p: 2, mb: 2, maxHeight: 320, overflow: "auto", whiteSpace: "pre-wrap" }}
                >
                    {form.form_body}
                </Paper>
                {asksForAnswers && (
                    <TextField
                        label="Your answers (to the numbered questions above)"
                        value={answers}
                        onChange={(e) => setAnswers(e.target.value)}
                        multiline
                        minRows={6}
                        fullWidth
                        sx={{ mb: 2 }}
                        placeholder={"1. ...\n2. ...\n3. ..."}
                    />
                )}
                <TextField
                    label="Type your full legal name to sign"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    required
                    fullWidth
                    sx={{ mb: 1 }}
                />
                <Box
                    sx={{
                        mb: 1,
                        px: 2,
                        py: 1.5,
                        border: "1px dashed",
                        borderColor: "divider",
                        borderRadius: 1,
                        minHeight: 64,
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "space-between",
                        gap: 2,
                    }}
                >
                    <Typography sx={{ fontFamily: SIGNATURE_FONT, fontSize: "2rem", lineHeight: 1.2, overflow: "hidden" }}>
                        {name || "\u00A0"}
                    </Typography>
                    <Typography variant="caption" color="text.secondary" sx={{ flexShrink: 0 }}>
                        Signature preview
                    </Typography>
                </Box>
                <FormControlLabel
                    control={<Checkbox checked={agreed} onChange={(e) => setAgreed(e.target.checked)} />}
                    label="I have read this form and agree that typing my name above constitutes my electronic signature."
                />
            </DialogContent>
            <DialogActions>
                <Button onClick={onClose}>Cancel</Button>
                <Button
                    variant="contained"
                    onClick={handleSign}
                    disabled={busy || !agreed || name.trim().length < 3}
                >
                    {busy ? "Signing..." : "Sign Form"}
                </Button>
            </DialogActions>
        </Dialog>
    );
}

export default function ParentFormsPage() {
    const [forms, setForms] = useState(null);
    const [error, setError] = useState(null);
    const [loading, setLoading] = useState(true);
    const [signTarget, setSignTarget] = useState(null);
    const [viewTarget, setViewTarget] = useState(null);

    const load = () => {
        portalApi
            .forms()
            .then(setForms)
            .catch((err) => setError(err.message))
            .finally(() => setLoading(false));
    };

    useEffect(load, []);

    if (loading) {
        return (
            <Box sx={{ display: "flex", justifyContent: "center", py: 6 }}>
                <CircularProgress />
            </Box>
        );
    }

    if (error) {
        return <Alert severity="error">{error}</Alert>;
    }

    const pending = forms.filter((f) => f.status === "pending");
    const signed = forms.filter((f) => f.status === "signed");

    return (
        <Box>
            <Typography variant="h4" gutterBottom>
                Enrollment Forms
            </Typography>

            {forms.length === 0 && (
                <Alert severity="info">No forms to sign right now.</Alert>
            )}

            {pending.length > 0 && (
                <>
                    <Typography variant="h6" sx={{ mt: 2, mb: 1 }}>
                        Waiting for your signature
                    </Typography>
                    <Stack spacing={1}>
                        {pending.map((form) => (
                            <Card key={form.id}>
                                <CardContent
                                    sx={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}
                                >
                                    <Box>
                                        <Typography>{form.form_name}</Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            For {form.child_name}
                                        </Typography>
                                    </Box>
                                    <Button variant="contained" onClick={() => setSignTarget(form)}>
                                        Review & Sign
                                    </Button>
                                </CardContent>
                            </Card>
                        ))}
                    </Stack>
                </>
            )}

            {signed.length > 0 && (
                <>
                    <Typography variant="h6" sx={{ mt: 3, mb: 1 }}>
                        Completed
                    </Typography>
                    <Stack spacing={1}>
                        {signed.map((form) => (
                            <Card key={form.id}>
                                <CardContent
                                    sx={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}
                                >
                                    <Box>
                                        <Typography>{form.form_name}</Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            For {form.child_name} — signed by {form.signed_by_name} on{" "}
                                            {new Date(form.signed_at).toLocaleDateString()}
                                        </Typography>
                                    </Box>
                                    <Chip label="Signed" color="success" size="small" onClick={() => setViewTarget(form)} />
                                </CardContent>
                            </Card>
                        ))}
                    </Stack>
                </>
            )}

            {signTarget && (
                <SignDialog form={signTarget} onClose={() => setSignTarget(null)} onSigned={load} />
            )}

            {viewTarget && (
                <Dialog open onClose={() => setViewTarget(null)} maxWidth="md" fullWidth>
                    <DialogTitle>{viewTarget.form_name} (signed)</DialogTitle>
                    <DialogContent>
                        <Paper variant="outlined" sx={{ p: 2, whiteSpace: "pre-wrap", maxHeight: 300, overflow: "auto" }}>
                            {viewTarget.form_body}
                        </Paper>
                        {viewTarget.response_text && (
                            <>
                                <Typography variant="subtitle2" sx={{ mt: 2 }}>Your answers</Typography>
                                <Paper variant="outlined" sx={{ p: 2, whiteSpace: "pre-wrap" }}>
                                    {viewTarget.response_text}
                                </Paper>
                            </>
                        )}
                        <Typography sx={{ fontFamily: SIGNATURE_FONT, fontSize: "2rem", mt: 2 }}>
                            {viewTarget.signed_by_name}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            Signed by {viewTarget.signed_by_name} on {new Date(viewTarget.signed_at).toLocaleString()}
                        </Typography>
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => setViewTarget(null)}>Close</Button>
                    </DialogActions>
                </Dialog>
            )}
        </Box>
    );
}
