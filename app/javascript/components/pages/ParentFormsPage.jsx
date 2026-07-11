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

function SignDialog({ form, onClose, onSigned }) {
    const [name, setName] = useState("");
    const [agreed, setAgreed] = useState(false);
    const [error, setError] = useState(null);
    const [busy, setBusy] = useState(false);

    const handleSign = async () => {
        setError(null);
        setBusy(true);
        try {
            await portalApi.signForm(form.id, name);
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
                <TextField
                    label="Type your full legal name to sign"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    required
                    fullWidth
                    sx={{ mb: 1 }}
                />
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
                        <Paper variant="outlined" sx={{ p: 2, whiteSpace: "pre-wrap" }}>
                            {viewTarget.form_body}
                        </Paper>
                        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
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
