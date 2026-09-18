import { useState, useEffect, useMemo, useCallback } from "react";
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
    Chip,
    Stack,
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import ArrowForwardIcon from "@mui/icons-material/ArrowForward";
import DownloadIcon from "@mui/icons-material/Download";
import DrawIcon from "@mui/icons-material/Draw";
import { staffDocumentsApi } from "../../utils/api";
import { useAuth } from "../../contexts/AuthContext";
import FormDocument, { hasFormFields, validateForm, SIGNATURE_FONT } from "../shared/FormDocument";
import EarthkinLoader from "../shared/EarthkinLoader";
import { statusLabel } from "./StaffDocumentsPage";

// The amber ring drawn around whichever field is the next thing to do. Borrowed
// from the e-signature services everyone has already used, because someone
// signing a notice should never have to hunt for what the portal wants next.
const activeRing = {
    outline: "3px solid",
    outlineColor: "warning.main",
    outlineOffset: "3px",
    borderRadius: 1,
    animation: "guidePulse 1.9s ease-in-out infinite",
    "@keyframes guidePulse": {
        "0%, 100%": { boxShadow: "0 0 0 0 rgba(237, 108, 2, 0.35)" },
        "50%": { boxShadow: "0 0 0 12px rgba(237, 108, 2, 0)" },
    },
};

// A small "do this next" flag pinned above the active field.
function StepTag({ show, label }) {
    if (!show) return null;
    return (
        <Chip
            size="small"
            label={label}
            color="warning"
            sx={{ mb: 0.75, fontWeight: 700, letterSpacing: 0.4 }}
        />
    );
}

export default function StaffDocumentSignPage() {
    const { id } = useParams();
    const navigate = useNavigate();
    const { user } = useAuth();
    const isAdmin = user?.role === "admin";

    const [doc, setDoc] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [name, setName] = useState("");
    const [comments, setComments] = useState("");
    const [fields, setFields] = useState({});
    const [agreed, setAgreed] = useState(false);
    const [busy, setBusy] = useState(false);
    const [fieldErrors, setFieldErrors] = useState({});
    // Optional steps stay in the sequence until the signer waves them off, so
    // the guide can offer them without ever blocking on them.
    const [skipped, setSkipped] = useState({});

    useEffect(() => {
        staffDocumentsApi
            .get(id)
            .then((found) => {
                setDoc(found);
                setFields(found.form_fields || {});
                // The audit trail exists to show the employee read the notice,
                // so only their own views are recorded.
                if (!isAdmin) staffDocumentsApi.view(found.id).catch(() => {});
            })
            .catch((err) => setError(err.message))
            .finally(() => setLoading(false));
    }, [id, isAdmin]);

    const handleSign = async () => {
        setError(null);

        if (!isAdmin && doc && hasFormFields(doc.body)) {
            const validationErrors = validateForm(doc.body, fields);
            setFieldErrors(validationErrors);
            const firstErrorKey = Object.keys(validationErrors)[0];
            if (firstErrorKey) {
                setError("Please complete the highlighted required fields before signing.");
                document
                    .getElementById(`field-${firstErrorKey}`)
                    ?.scrollIntoView({ behavior: "smooth", block: "center" });
                return;
            }
        }

        setBusy(true);
        try {
            const updated = await staffDocumentsApi.sign(doc.id, name, comments, fields);
            setDoc(updated);
            setAgreed(false);
            setName("");
        } catch (err) {
            setError(err.message);
        } finally {
            setBusy(false);
        }
    };

    const structured = doc ? hasFormFields(doc.body) : false;
    const alreadySigned = doc && (isAdmin ? doc.director_signed_at : doc.employee_signed_at);
    const signedName = name.trim().length >= 3;

    // The ordered walkthrough. The signature lives inside the document when the
    // body carries a [[signature]] marker, and in the panel below otherwise, so
    // the first step points at whichever one is on screen.
    const steps = useMemo(() => {
        if (!doc || alreadySigned) return [];
        const signatureTarget = isAdmin || !structured ? "staff-doc-name" : "form-signature-block";
        const list = [
            {
                key: "signature",
                target: signatureTarget,
                label: "Type your full legal name",
                done: signedName,
            },
        ];
        if (!isAdmin) {
            list.push({
                key: "comments",
                target: "staff-doc-comments",
                label: "Add comments of your own",
                optional: true,
                done: comments.trim().length > 0,
            });
        }
        list.push({
            key: "acknowledge",
            target: "staff-doc-acknowledge",
            label: isAdmin ? "Confirm your counter-signature" : "Confirm you received and read the notice",
            done: agreed,
        });
        list.push({
            key: "submit",
            target: "staff-doc-submit",
            label: isAdmin ? "Click Counter-sign to finish" : "Click Sign to finish",
            done: false,
        });
        return list;
    }, [doc, alreadySigned, isAdmin, structured, signedName, comments, agreed]);

    const activeStep = steps.find((step) => !step.done && !skipped[step.key]);
    const activeIndex = activeStep ? steps.indexOf(activeStep) : -1;
    const completedCount = steps.filter((step) => step.done || skipped[step.key]).length;

    const goToStep = useCallback((step) => {
        const el = document.getElementById(step.target);
        if (!el) return;
        el.scrollIntoView({ behavior: "smooth", block: "center" });
        const focusable = el.matches("input, textarea") ? el : el.querySelector("input, textarea, button");
        // Let the smooth scroll settle before stealing focus, or the browser
        // jumps the page a second time.
        setTimeout(() => focusable?.focus({ preventScroll: true }), 450);
    }, []);

    if (loading) {
        return (
            <Box sx={{ display: "flex", justifyContent: "center", py: 6 }}>
                <EarthkinLoader />
            </Box>
        );
    }

    if (!doc) {
        return error ? <Alert severity="error">{error}</Alert> : null;
    }

    const status = statusLabel(doc);
    const canSign = agreed && signedName;
    // The [[signature]] block inside the document is always the employee's,
    // whoever is looking at it. The director signs in their own panel below.
    const signerLabel = `${doc.teacher_name}${doc.employee_position ? `, ${doc.employee_position}` : ""}`;
    const isActive = (key) => activeStep?.key === key;

    return (
        <Box sx={{ maxWidth: 860, mx: "auto", pb: activeStep ? 14 : 6 }}>
            <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 1, flexWrap: "wrap", gap: 1 }}>
                <Button startIcon={<ArrowBackIcon />} onClick={() => navigate("/staff-documents")}>
                    Back to Documents
                </Button>
                <Button
                    startIcon={<DownloadIcon />}
                    variant="outlined"
                    component="a"
                    href={staffDocumentsApi.pdfPath(doc.id)}
                >
                    Download PDF
                </Button>
            </Box>

            <Stack direction="row" spacing={2} alignItems="center" sx={{ mb: 2, flexWrap: "wrap" }}>
                <Typography variant="h4">{doc.title}</Typography>
                <Chip label={status.label} color={status.color} size="small" />
            </Stack>
            {isAdmin && (
                <Typography color="text.secondary" sx={{ mb: 2 }}>
                    Issued to {doc.teacher_name}
                    {doc.employee_position ? `, ${doc.employee_position}` : ""} on{" "}
                    {new Date(doc.created_at).toLocaleDateString()}
                </Typography>
            )}

            {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

            <Paper
                sx={{
                    p: { xs: 2, sm: 4 },
                    whiteSpace: structured ? "normal" : "pre-wrap",
                    // Ring the signature block where it sits inside the document.
                    ...(isActive("signature") && activeStep.target === "form-signature-block"
                        ? { "& #form-signature-block": activeRing }
                        : {}),
                }}
            >
                {structured ? (
                    <FormDocument
                        body={doc.body}
                        values={fields}
                        readOnly={Boolean(doc.employee_signed_at) || isAdmin}
                        onChange={(key, value) => {
                            setFields((prev) => ({ ...prev, [key]: value }));
                            setFieldErrors((prev) => {
                                const next = { ...prev };
                                delete next[key];
                                return next;
                            });
                        }}
                        signatureName={doc.employee_signed_by_name || (isAdmin ? "" : name)}
                        onSignatureChange={setName}
                        signedAt={doc.employee_signed_at}
                        errors={fieldErrors}
                        signerLabel={signerLabel}
                    />
                ) : (
                    doc.body
                )}
            </Paper>

            {/* The employee's written comments. The section is always present,
                so an admin previewing a notice sees what the employee will be
                asked, and a signed notice shows plainly that none were left. */}
            {doc.employee_signed_at ? (
                <Box sx={{ mt: 2 }}>
                    <Typography variant="subtitle2">Comments recorded with this signature</Typography>
                    <Paper
                        variant="outlined"
                        sx={{
                            p: 2,
                            whiteSpace: "pre-wrap",
                            fontStyle: doc.employee_comments ? "normal" : "italic",
                            color: doc.employee_comments ? "text.primary" : "text.secondary",
                        }}
                    >
                        {doc.employee_comments || "(none provided)"}
                    </Paper>
                </Box>
            ) : isAdmin ? (
                <Box sx={{ mt: 2 }}>
                    <Typography variant="subtitle2">Comments the employee can add</Typography>
                    <Paper variant="outlined" sx={{ p: 2, fontStyle: "italic", color: "text.secondary" }}>
                        The employee can write comments here when they sign. Anything they add is
                        recorded with their signature and printed on the PDF.
                    </Paper>
                </Box>
            ) : (
                <Box sx={{ mt: 2 }}>
                    <StepTag show={isActive("comments")} label="Optional" />
                    <TextField
                        id="staff-doc-comments"
                        label="Your comments (optional)"
                        value={comments}
                        onChange={(e) => setComments(e.target.value)}
                        multiline
                        minRows={4}
                        fullWidth
                        helperText="Anything you would like recorded alongside your acknowledgment."
                        sx={isActive("comments") ? activeRing : undefined}
                    />
                </Box>
            )}

            {doc.director_signed_at && (
                <Box sx={{ mt: 3 }}>
                    <Typography sx={{ fontFamily: SIGNATURE_FONT, fontSize: "2rem" }}>
                        {doc.director_signed_by_name}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                        Counter-signed {new Date(doc.director_signed_at).toLocaleString()}
                    </Typography>
                </Box>
            )}

            {alreadySigned ? (
                <Alert severity="success" sx={{ mt: 3 }}>
                    {isAdmin
                        ? "You have counter-signed this document."
                        : "Your acknowledgment is recorded. You can download a PDF copy above."}
                </Alert>
            ) : (
                <Paper variant="outlined" sx={{ mt: 3, p: 2 }}>
                    <Typography variant="subtitle1" gutterBottom>
                        {isAdmin ? "Counter-sign this document" : "Acknowledge this notice"}
                    </Typography>
                    {/* A structured body carries its own [[signature]] block,
                        so the employee signs in place. Everyone else, and any
                        document without that marker, signs here. */}
                    {(isAdmin || !structured) && (
                        <>
                            <StepTag show={isActive("signature")} label="Sign here" />
                            <TextField
                                id="staff-doc-name"
                                label="Type your full legal name to sign"
                                value={name}
                                onChange={(e) => setName(e.target.value)}
                                required
                                fullWidth
                                sx={{ mb: 1, ...(isActive("signature") ? activeRing : {}) }}
                            />
                            <Typography sx={{ fontFamily: SIGNATURE_FONT, fontSize: "2rem", minHeight: 48 }}>
                                {name || " "}
                            </Typography>
                        </>
                    )}
                    <Box id="staff-doc-acknowledge" sx={{ py: 0.5, ...(isActive("acknowledge") ? activeRing : {}) }}>
                        <StepTag show={isActive("acknowledge")} label="Check this box" />
                        <FormControlLabel
                            control={<Checkbox checked={agreed} onChange={(e) => setAgreed(e.target.checked)} />}
                            label={
                                isAdmin
                                    ? "Typing my name constitutes my electronic counter-signature."
                                    : "I have received and read this notice, and typing my name constitutes my electronic signature. Signing records receipt, not agreement."
                            }
                        />
                    </Box>
                    <Box sx={{ mt: 1 }}>
                        <StepTag show={isActive("submit")} label="Last step" />
                        <Box
                            id="staff-doc-submit"
                            sx={{ display: "inline-block", ...(isActive("submit") ? activeRing : {}) }}
                        >
                            <Button
                                variant="contained"
                                size="large"
                                startIcon={<DrawIcon />}
                                onClick={handleSign}
                                disabled={busy || !canSign}
                            >
                                {busy ? "Signing..." : isAdmin ? "Counter-sign" : "Sign"}
                            </Button>
                        </Box>
                    </Box>
                </Paper>
            )}

            {/* The travelling "next thing to do" pill. Always on screen while
                anything is outstanding, so the next action is never more than
                one click away no matter where the reader has scrolled to. On
                the final step it turns green and signs directly. */}
            {activeStep && (
                <Paper
                    id="staff-doc-guide"
                    elevation={12}
                    sx={{
                        position: "fixed",
                        bottom: 24,
                        left: "50%",
                        transform: "translateX(-50%)",
                        zIndex: (theme) => theme.zIndex.appBar + 1,
                        bgcolor: activeStep.key === "submit" ? "success.main" : "warning.main",
                        color: activeStep.key === "submit" ? "success.contrastText" : "warning.contrastText",
                        borderRadius: 8,
                        px: 2,
                        py: 1,
                        display: "flex",
                        alignItems: "center",
                        gap: 1.5,
                        maxWidth: "calc(100vw - 32px)",
                    }}
                >
                    <Chip
                        size="small"
                        label={`${completedCount}/${steps.length}`}
                        sx={{ bgcolor: "rgba(0,0,0,0.18)", color: "inherit", fontWeight: 700 }}
                    />
                    <Box sx={{ minWidth: 0 }}>
                        <Typography variant="caption" sx={{ display: "block", opacity: 0.85, lineHeight: 1.2 }}>
                            {activeStep.key === "submit" ? "All set" : `Step ${activeIndex + 1} of ${steps.length}`}
                        </Typography>
                        <Typography variant="body2" sx={{ fontWeight: 700, lineHeight: 1.25 }}>
                            {activeStep.label}
                        </Typography>
                    </Box>
                    {activeStep.optional && (
                        <Button
                            size="small"
                            color="inherit"
                            onClick={() => setSkipped((prev) => ({ ...prev, [activeStep.key]: true }))}
                        >
                            Skip
                        </Button>
                    )}
                    {activeStep.key === "submit" ? (
                        <Button
                            size="small"
                            variant="contained"
                            color="inherit"
                            startIcon={<DrawIcon />}
                            onClick={handleSign}
                            disabled={busy}
                            sx={{ color: "success.dark", fontWeight: 700, whiteSpace: "nowrap" }}
                        >
                            {busy ? "Signing..." : isAdmin ? "Counter-sign" : "Sign"}
                        </Button>
                    ) : (
                        <Button
                            size="small"
                            variant="contained"
                            color="inherit"
                            endIcon={<ArrowForwardIcon />}
                            onClick={() => goToStep(activeStep)}
                            sx={{ color: "warning.dark", fontWeight: 700, whiteSpace: "nowrap" }}
                        >
                            Take me there
                        </Button>
                    )}
                </Paper>
            )}

        </Box>
    );
}
