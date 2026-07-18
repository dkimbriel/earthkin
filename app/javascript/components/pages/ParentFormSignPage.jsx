import { useState, useEffect, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
    Box,
    Typography,
    Button,
    Paper,
    Alert,
    TextField,
    FormControlLabel,
    Checkbox,
    Fab,
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import ArrowDownwardIcon from "@mui/icons-material/ArrowDownward";
import DownloadIcon from "@mui/icons-material/Download";
import DrawIcon from "@mui/icons-material/Draw";
import { portalApi } from "../../utils/api";
import FormDocument, { hasFormFields, validateForm, SIGNATURE_FONT } from "../shared/FormDocument";
import EarthkinLoader from "../shared/EarthkinLoader";

export default function ParentFormSignPage() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [form, setForm] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [name, setName] = useState("");
    const [answers, setAnswers] = useState("");
    const [fields, setFields] = useState({});
    const [agreed, setAgreed] = useState(false);
    const [busy, setBusy] = useState(false);
    const [signatureVisible, setSignatureVisible] = useState(false);
    const [fieldErrors, setFieldErrors] = useState({});
    const observerRef = useRef(null);

    useEffect(() => {
        portalApi
            .forms()
            .then((all) => {
                const found = all.find((f) => String(f.id) === String(id));
                if (!found) {
                    navigate("/forms");
                    return;
                }
                if (found.status === "signed") {
                    navigate("/forms");
                    return;
                }
                setForm(found);
                setFields(found.suggested_fields || {});
                portalApi.viewForm(found.id).catch(() => {});
            })
            .catch((err) => setError(err.message))
            .finally(() => setLoading(false));
    }, [id, navigate]);

    // Watch the signature block so the "scroll down to sign" prompt knows
    // when it has come into view.
    useEffect(() => {
        if (!form) return undefined;
        const target = document.getElementById("form-signature-block");
        if (!target) {
            setSignatureVisible(true);
            return undefined;
        }
        observerRef.current = new IntersectionObserver(
            (entries) => setSignatureVisible(entries.some((e) => e.isIntersecting)),
            { threshold: 0.2 }
        );
        observerRef.current.observe(target);
        return () => observerRef.current?.disconnect();
    }, [form]);

    const scrollToSignature = () => {
        document.getElementById("form-signature-block")?.scrollIntoView({ behavior: "smooth", block: "center" });
    };

    const handleSign = async () => {
        setError(null);

        // Client-side required-field check (the server enforces it too).
        const validationErrors = hasFormFields(form.form_body) ? validateForm(form.form_body, fields) : {};
        setFieldErrors(validationErrors);
        const firstErrorKey = Object.keys(validationErrors)[0];
        if (firstErrorKey) {
            setError("Please complete the highlighted required fields before signing.");
            document
                .getElementById(`field-${firstErrorKey}`)
                ?.scrollIntoView({ behavior: "smooth", block: "center" });
            return;
        }

        setBusy(true);
        try {
            await portalApi.signForm(form.id, name, answers, fields);
            navigate("/forms", { state: { justSigned: form.form_name } });
        } catch (err) {
            setError(err.message);
            setBusy(false);
        }
    };

    if (loading) {
        return (
            <Box sx={{ display: "flex", justifyContent: "center", py: 6 }}>
                <EarthkinLoader />
            </Box>
        );
    }

    if (!form) {
        return error ? <Alert severity="error">{error}</Alert> : null;
    }

    const structured = hasFormFields(form.form_body);
    const asksForAnswers = !structured && (form.form_body || "").includes("Your answers");
    const canSign = agreed && name.trim().length >= 3;

    return (
        <Box sx={{ maxWidth: 860, mx: "auto", pb: 12 }}>
            <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 1, flexWrap: "wrap", gap: 1 }}>
                <Button startIcon={<ArrowBackIcon />} onClick={() => navigate("/forms")}>
                    Back to Forms
                </Button>
                <Button
                    startIcon={<DownloadIcon />}
                    variant="outlined"
                    component="a"
                    href={`/api/portal/forms/${form.id}/pdf`}
                >
                    Download PDF
                </Button>
            </Box>

            <Typography variant="h4" gutterBottom>
                {form.form_name}
            </Typography>
            <Typography color="text.secondary" sx={{ mb: 2 }}>
                For {form.child_name} — review the form, fill in your details, and sign at the bottom.
            </Typography>

            {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

            <Paper sx={{ p: { xs: 2, sm: 4 }, whiteSpace: structured ? "normal" : "pre-wrap" }}>
                {structured ? (
                    <FormDocument
                        body={form.form_body}
                        values={fields}
                        onChange={(key, value) => {
                            setFields((prev) => ({ ...prev, [key]: value }));
                            if (Object.keys(fieldErrors).length) {
                                setFieldErrors((prev) => {
                                    const next = { ...prev };
                                    delete next[key];
                                    Object.keys(next).forEach((k) => {
                                        if (k.startsWith("one-of:") && k.includes(key)) delete next[k];
                                    });
                                    return next;
                                });
                            }
                        }}
                        signatureName={name}
                        onSignatureChange={setName}
                        errors={fieldErrors}
                    />
                ) : (
                    form.form_body
                )}
            </Paper>

            {asksForAnswers && (
                <TextField
                    label="Your answers (to the numbered questions above)"
                    value={answers}
                    onChange={(e) => setAnswers(e.target.value)}
                    multiline
                    minRows={6}
                    fullWidth
                    sx={{ mt: 2 }}
                    placeholder={"1. ...\n2. ...\n3. ..."}
                />
            )}

            {!structured && (
                <Box id="form-signature-block" sx={{ mt: 2 }}>
                    <TextField
                        label="Type your full legal name to sign"
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        required
                        fullWidth
                        sx={{ mb: 1 }}
                    />
                    <Typography sx={{ fontFamily: SIGNATURE_FONT, fontSize: "2rem", minHeight: 48 }}>
                        {name || " "}
                    </Typography>
                </Box>
            )}

            {/* Floating prompt until the signature line is on screen */}
            {!signatureVisible && (
                <Fab
                    variant="extended"
                    color="primary"
                    onClick={scrollToSignature}
                    sx={{
                        position: "fixed",
                        bottom: 96,
                        left: "50%",
                        transform: "translateX(-50%)",
                        zIndex: (theme) => theme.zIndex.appBar,
                    }}
                >
                    <ArrowDownwardIcon sx={{ mr: 1 }} />
                    Scroll down to sign
                </Fab>
            )}

            {/* Sticky signing bar */}
            <Paper
                elevation={8}
                sx={{
                    position: "fixed",
                    bottom: 0,
                    left: { xs: 0, md: "220px" },
                    right: 0,
                    px: 3,
                    py: 1.5,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "space-between",
                    gap: 2,
                    flexWrap: "wrap",
                    zIndex: (theme) => theme.zIndex.appBar,
                }}
            >
                <FormControlLabel
                    control={<Checkbox checked={agreed} onChange={(e) => setAgreed(e.target.checked)} />}
                    label="I have read this form and agree that typing my name constitutes my electronic signature."
                    sx={{ flex: 1, minWidth: 280 }}
                />
                <Button
                    variant="contained"
                    size="large"
                    startIcon={<DrawIcon />}
                    onClick={canSign ? handleSign : scrollToSignature}
                    disabled={busy}
                >
                    {busy ? "Signing..." : canSign ? "Sign Form" : "Go to signature"}
                </Button>
            </Paper>
        </Box>
    );
}
