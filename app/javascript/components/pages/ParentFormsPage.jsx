import { useState, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import {
    Box,
    Typography,
    Card,
    CardContent,
    Chip,
    Alert,
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
import FormDocument, { hasFormFields, SIGNATURE_FONT } from "../shared/FormDocument";
import EarthkinLoader from "../shared/EarthkinLoader";

export default function ParentFormsPage() {
    const navigate = useNavigate();
    const location = useLocation();
    const justSigned = location.state?.justSigned;
    const [forms, setForms] = useState(null);
    const [error, setError] = useState(null);
    const [loading, setLoading] = useState(true);
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
                <EarthkinLoader />
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

            {justSigned && (
                <Alert severity="success" sx={{ mb: 2 }}>
                    "{justSigned}" signed — thank you! You can review it below or download a PDF copy.
                </Alert>
            )}

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
                                    <Button variant="contained" onClick={() => navigate(`/forms/${form.id}/sign`)}>
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

            {viewTarget && (
                <Dialog open onClose={() => setViewTarget(null)} maxWidth="md" fullWidth>
                    <DialogTitle>{viewTarget.form_name} (signed)</DialogTitle>
                    <DialogContent>
                        <Paper
                            variant="outlined"
                            sx={{
                                p: 3,
                                whiteSpace: hasFormFields(viewTarget.form_body) ? "normal" : "pre-wrap",
                                maxHeight: 480,
                                overflow: "auto",
                            }}
                        >
                            {hasFormFields(viewTarget.form_body) ? (
                                <FormDocument
                                    body={viewTarget.form_body}
                                    values={viewTarget.form_fields || {}}
                                    readOnly
                                    signatureName={viewTarget.signed_by_name}
                                    signedAt={viewTarget.signed_at}
                                />
                            ) : (
                                viewTarget.form_body
                            )}
                        </Paper>
                        {viewTarget.response_text && (
                            <>
                                <Typography variant="subtitle2" sx={{ mt: 2 }}>Your answers</Typography>
                                <Paper variant="outlined" sx={{ p: 2, whiteSpace: "pre-wrap" }}>
                                    {viewTarget.response_text}
                                </Paper>
                            </>
                        )}
                        {!hasFormFields(viewTarget.form_body) && (
                            <Typography sx={{ fontFamily: SIGNATURE_FONT, fontSize: "2rem", mt: 2 }}>
                                {viewTarget.signed_by_name}
                            </Typography>
                        )}
                        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                            Signed by {viewTarget.signed_by_name} on {new Date(viewTarget.signed_at).toLocaleString()}
                        </Typography>
                    </DialogContent>
                    <DialogActions>
                        <Button component="a" href={`/api/portal/forms/${viewTarget.id}/pdf`}>
                            Download PDF
                        </Button>
                        <Button onClick={() => setViewTarget(null)}>Close</Button>
                    </DialogActions>
                </Dialog>
            )}
        </Box>
    );
}
