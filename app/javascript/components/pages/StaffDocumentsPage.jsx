import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
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
    MenuItem,
} from "@mui/material";
import DescriptionIcon from "@mui/icons-material/Description";
import { staffDocumentsApi } from "../../utils/api";
import { useAuth } from "../../contexts/AuthContext";
import EarthkinLoader from "../shared/EarthkinLoader";

// What each status means to the person looking at the list. A document sits in
// partially_signed whether the employee or the director signed first, so the
// label is worked out from the timestamps rather than the status alone.
export function statusLabel(doc) {
    if (doc.status === "signed") return { label: "Complete", color: "success" };
    if (doc.employee_signed_at) return { label: "Awaiting counter-signature", color: "warning" };
    if (doc.director_signed_at) return { label: "Awaiting employee signature", color: "warning" };
    return { label: "Not yet signed", color: "default" };
}

function IssueDialog({ onClose, onIssued }) {
    const [options, setOptions] = useState(null);
    const [error, setError] = useState(null);
    const [busy, setBusy] = useState(false);
    const [teacherId, setTeacherId] = useState("");
    const [templateId, setTemplateId] = useState("");
    const [title, setTitle] = useState("");
    const [position, setPosition] = useState("");
    const [body, setBody] = useState("");

    useEffect(() => {
        staffDocumentsApi
            .templates()
            .then((data) => {
                setOptions(data);
                const first = data.templates[0];
                if (first) {
                    setTemplateId(first.id);
                    setTitle(first.name);
                    setBody(first.body);
                }
            })
            .catch((err) => setError(err.message));
    }, []);

    const pickTemplate = (id) => {
        setTemplateId(id);
        const template = options.templates.find((t) => t.id === id);
        if (template) {
            setTitle(template.name);
            setBody(template.body);
        }
    };

    const handleIssue = async () => {
        setError(null);
        setBusy(true);
        try {
            const doc = await staffDocumentsApi.issue({
                teacher_id: teacherId,
                form_template_id: templateId,
                title,
                employee_position: position,
                body,
            });
            onIssued(doc);
        } catch (err) {
            setError(err.message);
            setBusy(false);
        }
    };

    return (
        <Dialog open onClose={onClose} maxWidth="md" fullWidth>
            <DialogTitle>Issue a staff document</DialogTitle>
            <DialogContent>
                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                {!options ? (
                    <Box sx={{ display: "flex", justifyContent: "center", py: 4 }}>
                        <EarthkinLoader />
                    </Box>
                ) : (
                    <Stack spacing={2} sx={{ mt: 1 }}>
                        <TextField
                            select
                            label="Employee"
                            value={teacherId}
                            onChange={(e) => setTeacherId(e.target.value)}
                            required
                            fullWidth
                        >
                            {options.teachers.map((t) => (
                                <MenuItem key={t.id} value={t.id}>
                                    {t.name}
                                </MenuItem>
                            ))}
                        </TextField>
                        <TextField
                            select
                            label="Template"
                            value={templateId}
                            onChange={(e) => pickTemplate(e.target.value)}
                            fullWidth
                        >
                            {options.templates.map((t) => (
                                <MenuItem key={t.id} value={t.id}>
                                    {t.name}
                                </MenuItem>
                            ))}
                        </TextField>
                        <TextField
                            label="Document title"
                            value={title}
                            onChange={(e) => setTitle(e.target.value)}
                            required
                            fullWidth
                        />
                        <TextField
                            label="Position at time of notice"
                            value={position}
                            onChange={(e) => setPosition(e.target.value)}
                            placeholder="Lead Teacher"
                            fullWidth
                        />
                        <TextField
                            label="Document text"
                            value={body}
                            onChange={(e) => setBody(e.target.value)}
                            multiline
                            minRows={14}
                            fullWidth
                            helperText={`Available tokens: ${options.known_tokens
                                .map((t) => `{{${t}}}`)
                                .join(", ")}. They are filled in once, when the document is issued.`}
                        />
                        <Alert severity="info">
                            The text is copied onto this employee's document when you issue it. Editing the
                            template later will not change a document already issued.
                        </Alert>
                    </Stack>
                )}
            </DialogContent>
            <DialogActions>
                <Button onClick={onClose}>Cancel</Button>
                <Button
                    variant="contained"
                    onClick={handleIssue}
                    disabled={busy || !teacherId || !title.trim() || !body.trim()}
                >
                    {busy ? "Issuing..." : "Issue Document"}
                </Button>
            </DialogActions>
        </Dialog>
    );
}

export default function StaffDocumentsPage() {
    const navigate = useNavigate();
    const { user } = useAuth();
    const isAdmin = user?.role === "admin";
    const [documents, setDocuments] = useState(null);
    const [error, setError] = useState(null);
    const [loading, setLoading] = useState(true);
    const [issuing, setIssuing] = useState(false);

    const load = () => {
        staffDocumentsApi
            .list()
            .then(setDocuments)
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

    const needsMe = documents.filter((doc) =>
        isAdmin ? !doc.director_signed_at : !doc.employee_signed_at
    );
    const rest = documents.filter((doc) => !needsMe.includes(doc));

    const renderCard = (doc) => {
        const status = statusLabel(doc);
        return (
            <Card key={doc.id}>
                <CardContent
                    sx={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 2 }}
                >
                    <Box sx={{ minWidth: 0 }}>
                        <Typography>{doc.title}</Typography>
                        <Typography variant="body2" color="text.secondary">
                            {isAdmin ? `${doc.teacher_name}, ` : ""}
                            issued {new Date(doc.created_at).toLocaleDateString()}
                        </Typography>
                    </Box>
                    <Stack direction="row" spacing={1} alignItems="center">
                        <Chip label={status.label} color={status.color} size="small" />
                        <Button variant="contained" onClick={() => navigate(`/staff-documents/${doc.id}`)}>
                            Open
                        </Button>
                    </Stack>
                </CardContent>
            </Card>
        );
    };

    return (
        <Box>
            <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 2, gap: 2, flexWrap: "wrap" }}>
                <Typography variant="h4">{isAdmin ? "Staff Documents" : "My Documents"}</Typography>
                {isAdmin && (
                    <Button variant="contained" startIcon={<DescriptionIcon />} onClick={() => setIssuing(true)}>
                        Issue Document
                    </Button>
                )}
            </Box>

            {documents.length === 0 && (
                <Alert severity="info">
                    {isAdmin ? "No staff documents have been issued yet." : "You have no documents to review."}
                </Alert>
            )}

            {needsMe.length > 0 && (
                <>
                    <Typography variant="h6" sx={{ mt: 2, mb: 1 }}>
                        {isAdmin ? "Waiting for your counter-signature" : "Waiting for your signature"}
                    </Typography>
                    <Stack spacing={1}>{needsMe.map(renderCard)}</Stack>
                </>
            )}

            {rest.length > 0 && (
                <>
                    <Typography variant="h6" sx={{ mt: 3, mb: 1 }}>
                        {isAdmin ? "All documents" : "Completed"}
                    </Typography>
                    <Stack spacing={1}>{rest.map(renderCard)}</Stack>
                </>
            )}

            {issuing && (
                <IssueDialog
                    onClose={() => setIssuing(false)}
                    onIssued={(doc) => {
                        setIssuing(false);
                        navigate(`/staff-documents/${doc.id}`);
                    }}
                />
            )}
        </Box>
    );
}
