import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
    Box,
    Typography,
    Button,
    Paper,
    Chip,
    Card,
    CardContent,
    Avatar,
    ButtonGroup,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Autocomplete,
    TextField,
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableRow,
} from "@mui/material";
import InfoOutlinedIcon from "@mui/icons-material/InfoOutlined";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import EditIcon from "@mui/icons-material/Edit";
import EventRepeatIcon from "@mui/icons-material/EventRepeat";
import CheckCircleIcon from "@mui/icons-material/CheckCircle";
import ContentCopyIcon from "@mui/icons-material/ContentCopy";
import LinkIcon from "@mui/icons-material/Link";
import CodeIcon from "@mui/icons-material/Code";
import ShareIcon from "@mui/icons-material/Share";
import EmailIcon from "@mui/icons-material/Email";
import AddIcon from "@mui/icons-material/Add";
import DeleteIcon from "@mui/icons-material/Delete";
import IconButton from "@mui/material/IconButton";
import Alert from "@mui/material/Alert";
import Snackbar from "@mui/material/Snackbar";
import Grid from "@mui/material/Grid";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import GenerateClassesDialog from "../shared/GenerateClassesDialog";
import EarthkinLoader from "../shared/EarthkinLoader";
import { useAuth } from "../../contexts/AuthContext";
import {
    programsApi,
    programClassesApi,
    programEnrollmentsApi,
    childrenApi,
    locationsApi,
    teachersApi,
    paymentPlansApi,
} from "../../utils/api";

const isClassComplete = (classItem) => {
    if (!classItem.date) return false;
    const [year, month, day] = classItem.date.split("-");
    const classDate = new Date(year, month - 1, day);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return classDate < today;
};

const classColumns = [
    {
        key: "status",
        label: "",
        render: (row) =>
            isClassComplete(row) ? (
                <CheckCircleIcon fontSize="small" color="success" />
            ) : null,
    },
    { key: "name", label: "Class Name" },
    {
        key: "date",
        label: "Date",
        render: (row) => {
            if (!row.date) return "—";
            // Parse date without timezone conversion (Rails returns "YYYY-MM-DD")
            const [year, month, day] = row.date.split("-");
            return new Date(year, month - 1, day).toLocaleDateString();
        },
    },
    {
        key: "time",
        label: "Time",
        render: (row) => {
            if (!row.start_time) return "—";
            const formatTime = (timeStr) => {
                // Extract time portion without timezone conversion (Rails returns "2000-01-01T08:00:00.000Z")
                const match = timeStr.match(/T(\d{2}):(\d{2})/);
                if (!match) return timeStr;
                const hours = parseInt(match[1], 10);
                const minutes = match[2];
                const period = hours >= 12 ? "PM" : "AM";
                const displayHours = hours % 12 || 12;
                return `${displayHours}:${minutes} ${period}`;
            };
            const start = formatTime(row.start_time);
            const end = row.end_time ? formatTime(row.end_time) : "";
            return end ? `${start} – ${end}` : start;
        },
    },
    {
        key: "location",
        label: "Location",
        render: (row) => row.location?.name || "—",
    },
];

const enrollmentColumns = [
    {
        key: "child",
        label: "Child",
        render: (row) => `${row.child?.first_name} ${row.child?.last_name}`,
    },
    {
        key: "status",
        label: "Status",
        render: (row) => (
            <Chip
                label={row.status}
                color={
                    row.status === "confirmed"
                        ? "success"
                        : row.status === "cancelled"
                        ? "error"
                        : "default"
                }
                size="small"
            />
        ),
    },
    {
        key: "payment_plan",
        label: "Payment Plan",
        render: (row) => row.enrollment_payment_plan?.payment_plan?.name || "—",
    },
    {
        key: "balance",
        label: "Balance Due",
        render: (row) => {
            const balance = parseFloat(row.balance_due) || 0;
            return (
                <Chip
                    label={`$${balance.toFixed(2)}`}
                    color={balance > 0 ? "warning" : "success"}
                    size="small"
                />
            );
        },
    },
];

const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const formatSchedule = (schedule) => {
    if (!schedule || schedule.length === 0) return "—";
    if (schedule.length === 1) {
        return `Due: ${monthNames[schedule[0].month - 1]} ${schedule[0].day}`;
    }
    // Show first and last months for multi-payment plans
    const first = schedule[0];
    const last = schedule[schedule.length - 1];
    return `${monthNames[first.month - 1]} ${first.day} – ${monthNames[last.month - 1]} ${last.day}`;
};

// paymentPlanColumns is defined inside the component to access state

export default function ProgramDetailPage() {
    const { user } = useAuth();
    const isAdmin = user?.role === "admin";
    const { id } = useParams();
    const navigate = useNavigate();
    const [program, setProgram] = useState(null);
    const [enrollments, setEnrollments] = useState([]);
    const [children, setChildren] = useState([]);
    const [locations, setLocations] = useState([]);
    const [allTeachers, setAllTeachers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showClassForm, setShowClassForm] = useState(false);
    const [showGenerateForm, setShowGenerateForm] = useState(false);
    const [showEnrollmentForm, setShowEnrollmentForm] = useState(false);
    const [showTeacherForm, setShowTeacherForm] = useState(false);
    const [selectedTeacher, setSelectedTeacher] = useState(null);
    const [deleteTarget, setDeleteTarget] = useState(null);
    const [showEnrollmentLinkModal, setShowEnrollmentLinkModal] = useState(false);
    const [copySuccess, setCopySuccess] = useState(null);
    const [showInviteModal, setShowInviteModal] = useState(false);
    const [inviteRecipients, setInviteRecipients] = useState([{ name: "", email: "" }]);
    const [inviteSending, setInviteSending] = useState(false);
    const [inviteSnackbar, setInviteSnackbar] = useState({ open: false, message: "", severity: "success" });
    const [paymentPlans, setPaymentPlans] = useState([]);
    const [showPaymentPlanForm, setShowPaymentPlanForm] = useState(false);
    const [editingPaymentPlan, setEditingPaymentPlan] = useState(null);
    const [deletePaymentPlanTarget, setDeletePaymentPlanTarget] = useState(null);
    const [scheduleModalPlan, setScheduleModalPlan] = useState(null);

    const enrollmentUrl = `${window.location.origin}/enroll?program_id=${id}`;
    const embedCode = `<iframe src="${enrollmentUrl}" width="100%" height="800" frameborder="0"></iframe>`;

    const paymentPlanColumns = [
        { key: "name", label: "Plan Name" },
        {
            key: "total_amount",
            label: "Total",
            render: (row) => `$${parseFloat(row.total_amount).toFixed(2)}`,
        },
        {
            key: "installment_count",
            label: "Payments",
            render: (row) => row.installment_count === 1 ? "1 payment" : `${row.installment_count} payments`,
        },
        {
            key: "installment_amount",
            label: "Per Payment",
            render: (row) => `$${parseFloat(row.installment_amount).toFixed(2)}`,
        },
        {
            key: "schedule",
            label: "Schedule",
            render: (row) => (
                <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
                    {formatSchedule(row.installment_schedule)}
                    {row.installment_schedule?.length > 0 && (
                        <IconButton
                            size="small"
                            onClick={(e) => {
                                e.stopPropagation();
                                setScheduleModalPlan(row);
                            }}
                            sx={{ p: 0.25 }}
                        >
                            <InfoOutlinedIcon fontSize="small" color="action" />
                        </IconButton>
                    )}
                </Box>
            ),
        },
        {
            key: "active",
            label: "Status",
            render: (row) => (
                <Chip
                    label={row.active ? "Active" : "Inactive"}
                    color={row.active ? "success" : "default"}
                    size="small"
                />
            ),
        },
    ];

    const handleCopy = (text, type) => {
        navigator.clipboard.writeText(text);
        setCopySuccess(type);
        setTimeout(() => setCopySuccess(null), 2000);
    };

    const handleAddRecipient = () => {
        setInviteRecipients([...inviteRecipients, { name: "", email: "" }]);
    };

    const handleRemoveRecipient = (index) => {
        setInviteRecipients(inviteRecipients.filter((_, i) => i !== index));
    };

    const handleRecipientChange = (index, field, value) => {
        const updated = [...inviteRecipients];
        updated[index][field] = value;
        setInviteRecipients(updated);
    };

    const handleSendInvites = async () => {
        const validRecipients = inviteRecipients.filter(r => r.name.trim() && r.email.trim());
        if (validRecipients.length === 0) {
            setInviteSnackbar({ open: true, message: "Please add at least one recipient with name and email", severity: "error" });
            return;
        }

        setInviteSending(true);
        try {
            const result = await programsApi.sendEnrollmentInvite(id, validRecipients);
            setInviteSnackbar({ open: true, message: `Successfully sent ${result.sent_count} invite(s)!`, severity: "success" });
            setShowInviteModal(false);
            setInviteRecipients([{ name: "", email: "" }]);
        } catch (error) {
            setInviteSnackbar({ open: true, message: error.message || "Failed to send invites", severity: "error" });
        } finally {
            setInviteSending(false);
        }
    };

    const handleCloseInviteModal = () => {
        setShowInviteModal(false);
        setInviteRecipients([{ name: "", email: "" }]);
    };

    const loadProgram = async () => {
        setLoading(true);
        try {
            const [programData, enrollmentsData, childrenData, locationsData, teachersData, paymentPlansData] =
                await Promise.all([
                    programsApi.get(id),
                    programEnrollmentsApi.list({ programId: id }),
                    childrenApi.list(),
                    locationsApi.list(),
                    teachersApi.list(),
                    paymentPlansApi.list(id),
                ]);
            setProgram(programData);
            setEnrollments(enrollmentsData);
            setChildren(childrenData);
            setLocations(locationsData);
            setAllTeachers(teachersData);
            setPaymentPlans(paymentPlansData);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadProgram();
    }, [id]);

    const handleCreateClass = async (formData) => {
        await programClassesApi.create({ ...formData, program_id: id });
        loadProgram();
    };

    const handleCreateEnrollment = async (formData) => {
        await programEnrollmentsApi.create({ ...formData, program_id: id });
        loadProgram();
    };

    const handleDeleteClass = async () => {
        if (deleteTarget?.type === "class") {
            await programClassesApi.delete(deleteTarget.item.id);
            setDeleteTarget(null);
            loadProgram();
        }
    };

    const handleAssignTeacher = async () => {
        if (!selectedTeacher) return;
        await programsApi.assignTeacher(id, selectedTeacher.id);
        setSelectedTeacher(null);
        setShowTeacherForm(false);
        loadProgram();
    };

    const handleUnassignTeacher = async (teacherId) => {
        await programsApi.unassignTeacher(id, teacherId);
        loadProgram();
    };

    const handleCreatePaymentPlan = async (formData) => {
        const installmentAmount = parseFloat(formData.total_amount) / parseInt(formData.installment_count, 10);
        await paymentPlansApi.create({
            ...formData,
            program_id: id,
            installment_amount: installmentAmount.toFixed(2),
        });
        setShowPaymentPlanForm(false);
        loadProgram();
    };

    const handleUpdatePaymentPlan = async (formData) => {
        const installmentAmount = parseFloat(formData.total_amount) / parseInt(formData.installment_count, 10);
        await paymentPlansApi.update(editingPaymentPlan.id, {
            ...formData,
            installment_amount: installmentAmount.toFixed(2),
        });
        setEditingPaymentPlan(null);
        loadProgram();
    };

    const handleDeletePaymentPlan = async () => {
        if (deletePaymentPlanTarget) {
            try {
                await paymentPlansApi.delete(deletePaymentPlanTarget.id);
                setDeletePaymentPlanTarget(null);
                loadProgram();
            } catch (error) {
                setDeletePaymentPlanTarget(null);
                setInviteSnackbar({
                    open: true,
                    message: error.message || "Cannot delete payment plan",
                    severity: "error"
                });
            }
        }
    };

    const classFormFields = [
        { name: "name", label: "Class Name", required: true },
        { name: "date", label: "Date", type: "date", required: true },
        { name: "start_time", label: "Start Time", type: "time" },
        { name: "end_time", label: "End Time", type: "time" },
        {
            name: "location_id",
            label: "Location",
            type: "select",
            options: locations.map((loc) => ({
                value: loc.id,
                label: loc.name,
            })),
        },
    ];

    const enrolledChildIds = enrollments.map((e) => e.child?.id);
    const availableChildren = children.filter(
        (c) => !enrolledChildIds.includes(c.id)
    );

    const assignedTeacherIds = program?.teachers?.map((t) => t.id) || [];
    const availableTeachers = allTeachers.filter(
        (t) => !assignedTeacherIds.includes(t.id)
    );

    const enrollmentFormFields = [
        {
            name: "child_id",
            label: "Child",
            type: "select",
            required: true,
            options: availableChildren.map((c) => ({
                value: c.id,
                label: `${c.first_name} ${c.last_name} (${
                    c.family?.name || "No family"
                })`,
            })),
        },
        {
            name: "rate_per_class",
            label: "Rate per Class ($)",
            type: "number",
            required: true,
        },
        {
            name: "status",
            label: "Status",
            type: "select",
            required: true,
            defaultValue: "pending",
            options: [
                { value: "pending", label: "Pending" },
                { value: "confirmed", label: "Confirmed" },
                { value: "cancelled", label: "Cancelled" },
            ],
        },
    ];

    const paymentPlanFormFields = [
        { name: "name", label: "Plan Name", required: true },
        { name: "description", label: "Description", multiline: true, rows: 2 },
        { name: "total_amount", label: "Total Amount ($)", type: "number", required: true },
        { name: "installment_count", label: "Number of Payments", type: "number", required: true, defaultValue: 1 },
        {
            name: "active",
            label: "Status",
            type: "select",
            required: true,
            defaultValue: true,
            options: [
                { value: true, label: "Active" },
                { value: false, label: "Inactive" },
            ],
        },
    ];

    if (loading) {
        return <EarthkinLoader />;
    }

    if (!program) {
        return <Typography>Program not found</Typography>;
    }

    const formatDate = (dateStr) => {
        if (!dateStr) return null;
        const [year, month, day] = dateStr.split("-");
        return new Date(year, month - 1, day).toLocaleDateString();
    };

    const isClassInFuture = (classItem) => {
        if (!classItem.date) return true;
        const [year, month, day] = classItem.date.split("-");
        const classDate = new Date(year, month - 1, day);
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        return classDate >= today;
    };

    return (
        <Box>
            <Box
                sx={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    mb: 2,
                }}
            >
                <Button
                    startIcon={<ArrowBackIcon />}
                    onClick={() => navigate("/programs")}
                >
                    Back to Programs
                </Button>
                <Box sx={{ display: "flex", gap: 1 }}>
                    <Button
                        startIcon={<ShareIcon />}
                        variant="contained"
                        color="primary"
                        onClick={() => setShowEnrollmentLinkModal(true)}
                    >
                        Get Enrollment Application Link
                    </Button>
                    {isAdmin && (
                        <Button
                            startIcon={<EmailIcon />}
                            variant="contained"
                            color="primary"
                            onClick={() => setShowInviteModal(true)}
                        >
                            Send Enrollment Invite
                        </Button>
                    )}
                    {isAdmin && (
                        <Button
                            startIcon={<EditIcon />}
                            variant="outlined"
                            onClick={() => navigate(`/programs/${id}/edit`)}
                        >
                            Edit Program
                        </Button>
                    )}
                </Box>
            </Box>

            <Typography variant="h4" gutterBottom>
                {program.name}
            </Typography>

            {program.description && (
                <Typography color="text.secondary" sx={{ mb: 2 }}>
                    {program.description}
                </Typography>
            )}

            <Box sx={{ display: "flex", gap: 1, mb: 3, flexWrap: "wrap", alignItems: "center" }}>
                {program.start_date && (
                    <Chip label={`Starts: ${formatDate(program.start_date)}`} />
                )}
                {program.end_date && (
                    <Chip label={`Ends: ${formatDate(program.end_date)}`} />
                )}
                <ButtonGroup size="small" sx={{ ml: "auto" }}>
                    <Button onClick={() => document.getElementById("teachers-section")?.scrollIntoView({ behavior: "smooth" })}>
                        Teachers
                    </Button>
                    <Button onClick={() => document.getElementById("classes-section")?.scrollIntoView({ behavior: "smooth" })}>
                        Classes
                    </Button>
                    <Button onClick={() => document.getElementById("enrollments-section")?.scrollIntoView({ behavior: "smooth" })}>
                        Enrollments
                    </Button>
                    <Button onClick={() => document.getElementById("payment-plans-section")?.scrollIntoView({ behavior: "smooth" })}>
                        Payment Plans
                    </Button>
                </ButtonGroup>
            </Box>

            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid size={{ xs: 12, md: 4 }}>
                    <Card>
                        <CardContent>
                            <Typography color="text.secondary" gutterBottom>
                                Enrollment
                            </Typography>
                            <Typography variant="h5">
                                {program.enrolled_count || 0}
                                {program.capacity
                                    ? ` / ${program.capacity}`
                                    : ""}
                            </Typography>
                            {program.pending_count > 0 && (
                                <Typography
                                    variant="body2"
                                    color="warning.main"
                                    sx={{ mb: 0.5 }}
                                >
                                    +{program.pending_count} pending
                                </Typography>
                            )}
                            {program.capacity && (
                                <Typography
                                    variant="body2"
                                    color="text.secondary"
                                >
                                    {Math.max(0, program.capacity -
                                        (program.enrolled_count || 0) -
                                        (program.pending_count || 0))}{" "}
                                    spots available
                                </Typography>
                            )}
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, md: 4 }}>
                    <Card style={{ height: "100%" }}>
                        <CardContent>
                            <Typography color="text.secondary" gutterBottom>
                                Payment Plans
                            </Typography>
                            <Typography variant="h5" color="success.main">
                                {paymentPlans.filter(p => p.active).length} active
                            </Typography>
                            {paymentPlans.length > 0 && (
                                <Typography variant="body2" color="text.secondary">
                                    {paymentPlans.length} total
                                </Typography>
                            )}
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, md: 4 }}>
                    <Card style={{ height: "100%" }}>
                        <CardContent>
                            <Typography color="text.secondary" gutterBottom>
                                Total Classes
                            </Typography>
                            <Typography variant="h5">
                                {program.program_classes?.length || 0}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            <Paper id="teachers-section" sx={{ p: 3, mb: 3 }}>
                <PageHeader
                    title="Teachers"
                    onAdd={isAdmin && availableTeachers.length > 0 ? () => setShowTeacherForm(true) : undefined}
                    addLabel="Assign Teacher"
                />
                {program.teachers?.length > 0 ? (
                    <Box sx={{ display: "flex", gap: 2, flexWrap: "wrap" }}>
                        {program.teachers.map((teacher) => (
                            <Chip
                                key={teacher.id}
                                avatar={
                                    <Avatar src={teacher.avatar_url}>
                                        {teacher.first_name?.[0]}{teacher.last_name?.[0]}
                                    </Avatar>
                                }
                                label={`${teacher.first_name} ${teacher.last_name}`}
                                onDelete={isAdmin ? () => handleUnassignTeacher(teacher.id) : undefined}
                                onClick={() => navigate(`/teachers/${teacher.id}`)}
                                clickable
                            />
                        ))}
                    </Box>
                ) : (
                    <Typography color="text.secondary">No teachers assigned yet.</Typography>
                )}
            </Paper>

            <Paper id="classes-section" sx={{ p: 3, mb: 3 }}>
                <PageHeader
                    title="Classes"
                    onAdd={isAdmin ? () => setShowClassForm(true) : undefined}
                    addLabel="Add Class"
                    actions={
                        isAdmin ? (
                            <Button
                                variant="outlined"
                                startIcon={<EventRepeatIcon />}
                                onClick={() => setShowGenerateForm(true)}
                            >
                                Generate from Pattern
                            </Button>
                        ) : undefined
                    }
                />
                <DataTable
                    columns={classColumns}
                    data={program.program_classes}
                    loading={false}
                    onDelete={isAdmin ? (item) =>
                        setDeleteTarget({ type: "class", item }) : undefined
                    }
                    canDelete={isClassInFuture}
                    onRowClick={isAdmin ? (row) => navigate(`/classes/${row.id}/edit`) : undefined}
                    canRowClick={isClassInFuture}
                    emptyMessage="No classes scheduled yet."
                />
            </Paper>

            <Paper id="enrollments-section" sx={{ p: 3, mb: 3 }}>
                <PageHeader
                    title="Enrollments"
                    onAdd={
                        isAdmin && availableChildren.length > 0
                            ? () => setShowEnrollmentForm(true)
                            : undefined
                    }
                    addLabel="Enroll Child"
                />
                <DataTable
                    columns={enrollmentColumns}
                    data={enrollments}
                    loading={false}
                    onRowClick={(row) => navigate(`/enrollments/${row.id}`)}
                    emptyMessage="No children enrolled yet."
                />
            </Paper>

            <Paper id="payment-plans-section" sx={{ p: 3 }}>
                <PageHeader
                    title="Payment Plans"
                    onAdd={isAdmin ? () => setShowPaymentPlanForm(true) : undefined}
                    addLabel="Add Payment Plan"
                />
                <DataTable
                    columns={paymentPlanColumns}
                    data={paymentPlans}
                    loading={false}
                    onEdit={isAdmin ? (row) => setEditingPaymentPlan(row) : undefined}
                    onDelete={isAdmin ? (row) => setDeletePaymentPlanTarget(row) : undefined}
                    emptyMessage="No payment plans configured yet."
                />
            </Paper>

            {showGenerateForm && (
                <GenerateClassesDialog
                    open={showGenerateForm}
                    onClose={() => setShowGenerateForm(false)}
                    program={program}
                    locations={locations}
                    onGenerated={(result) => {
                        setInviteSnackbar({
                            open: true,
                            message: `Created ${result.created_count} class${result.created_count === 1 ? "" : "es"}`,
                            severity: "success",
                        });
                        loadProgram();
                    }}
                />
            )}

            <FormDialog
                open={showClassForm}
                onClose={() => setShowClassForm(false)}
                onSubmit={handleCreateClass}
                title="Add Class"
                fields={classFormFields}
            />

            <FormDialog
                open={showEnrollmentForm}
                onClose={() => setShowEnrollmentForm(false)}
                onSubmit={handleCreateEnrollment}
                title="Enroll Child"
                fields={enrollmentFormFields}
            />

            <FormDialog
                open={showPaymentPlanForm}
                onClose={() => setShowPaymentPlanForm(false)}
                onSubmit={handleCreatePaymentPlan}
                title="Add Payment Plan"
                fields={paymentPlanFormFields}
            />

            <FormDialog
                open={!!editingPaymentPlan}
                onClose={() => setEditingPaymentPlan(null)}
                onSubmit={handleUpdatePaymentPlan}
                title="Edit Payment Plan"
                fields={paymentPlanFormFields}
                initialData={editingPaymentPlan}
            />

            <ConfirmDialog
                open={!!deletePaymentPlanTarget}
                onClose={() => setDeletePaymentPlanTarget(null)}
                onConfirm={handleDeletePaymentPlan}
                title="Delete Payment Plan"
                message={`Are you sure you want to delete "${deletePaymentPlanTarget?.name}"? This cannot be undone.`}
            />

            <Dialog
                open={!!scheduleModalPlan}
                onClose={() => setScheduleModalPlan(null)}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>
                    Payment Schedule: {scheduleModalPlan?.name}
                </DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        {scheduleModalPlan?.installment_count} payment(s) of ${parseFloat(scheduleModalPlan?.installment_amount || 0).toFixed(2)} each
                    </Typography>
                    <Table size="small">
                        <TableHead>
                            <TableRow>
                                <TableCell>#</TableCell>
                                <TableCell>Due Date</TableCell>
                                <TableCell align="right">Amount</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {scheduleModalPlan?.installment_schedule?.map((installment, index) => (
                                <TableRow key={index}>
                                    <TableCell>{index + 1}</TableCell>
                                    <TableCell>{monthNames[installment.month - 1]} {installment.day}</TableCell>
                                    <TableCell align="right">${parseFloat(installment.amount).toFixed(2)}</TableCell>
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setScheduleModalPlan(null)}>Close</Button>
                </DialogActions>
            </Dialog>

            <Dialog open={showTeacherForm} onClose={() => { setShowTeacherForm(false); setSelectedTeacher(null); }} maxWidth="sm" fullWidth>
                <DialogTitle>Assign Teacher</DialogTitle>
                <DialogContent>
                    <Autocomplete
                        sx={{ mt: 1 }}
                        options={availableTeachers}
                        getOptionLabel={(option) => option.full_name}
                        value={selectedTeacher}
                        onChange={(_, newValue) => setSelectedTeacher(newValue)}
                        renderOption={(props, option) => {
                            const { key, ...otherProps } = props;
                            return (
                                <Box component="li" key={key} {...otherProps} sx={{ display: "flex", alignItems: "center", gap: 1.5 }}>
                                    <Avatar src={option.avatar_url} sx={{ width: 32, height: 32 }}>
                                        {option.first_name?.[0]}{option.last_name?.[0]}
                                    </Avatar>
                                    {option.full_name}
                                </Box>
                            );
                        }}
                        renderInput={(params) => <TextField {...params} label="Select Teacher" />}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => { setShowTeacherForm(false); setSelectedTeacher(null); }}>Cancel</Button>
                    <Button onClick={handleAssignTeacher} variant="contained" disabled={!selectedTeacher}>Assign</Button>
                </DialogActions>
            </Dialog>

            <ConfirmDialog
                open={deleteTarget?.type === "class"}
                onClose={() => setDeleteTarget(null)}
                onConfirm={handleDeleteClass}
                title="Delete Class"
                message={`Are you sure you want to delete "${deleteTarget?.item?.name}"?`}
            />

            <Dialog
                open={showEnrollmentLinkModal}
                onClose={() => setShowEnrollmentLinkModal(false)}
                maxWidth="md"
                fullWidth
            >
                <DialogTitle>
                    <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
                        <LinkIcon /> Public Enrollment Link
                    </Box>
                </DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                        Share this link with families or embed it on your website
                    </Typography>

                    <Box sx={{ mb: 3 }}>
                        <Typography variant="caption" color="text.secondary" display="block" gutterBottom>
                            Direct Link
                        </Typography>
                        <Box sx={{ display: "flex", gap: 1, alignItems: "center" }}>
                            <TextField
                                fullWidth
                                size="small"
                                value={enrollmentUrl}
                                InputProps={{ readOnly: true }}
                            />
                            <Button
                                variant="contained"
                                size="small"
                                startIcon={<ContentCopyIcon />}
                                onClick={() => handleCopy(enrollmentUrl, 'link')}
                            >
                                {copySuccess === 'link' ? 'Copied!' : 'Copy'}
                            </Button>
                        </Box>
                    </Box>

                    <Box>
                        <Typography variant="caption" color="text.secondary" display="block" gutterBottom sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
                            <CodeIcon fontSize="small" /> Embed Code (iframe)
                        </Typography>
                        <Box sx={{ display: "flex", gap: 1, alignItems: "center" }}>
                            <TextField
                                fullWidth
                                size="small"
                                value={embedCode}
                                InputProps={{ readOnly: true }}
                                sx={{ fontFamily: "monospace", fontSize: "0.85rem" }}
                            />
                            <Button
                                variant="contained"
                                size="small"
                                startIcon={<ContentCopyIcon />}
                                onClick={() => handleCopy(embedCode, 'embed')}
                            >
                                {copySuccess === 'embed' ? 'Copied!' : 'Copy'}
                            </Button>
                        </Box>
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setShowEnrollmentLinkModal(false)}>
                        Close
                    </Button>
                </DialogActions>
            </Dialog>

            <Dialog
                open={showInviteModal}
                onClose={handleCloseInviteModal}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>
                    <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
                        <EmailIcon /> Send Enrollment Invite
                    </Box>
                </DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                        Send an email invitation to prospective families with a link to the enrollment application.
                    </Typography>

                    {inviteRecipients.map((recipient, index) => (
                        <Box key={index} sx={{ display: "flex", gap: 1, mb: 2, alignItems: "flex-start" }}>
                            <TextField
                                label="Name"
                                size="small"
                                value={recipient.name}
                                onChange={(e) => handleRecipientChange(index, "name", e.target.value)}
                                sx={{ flex: 1 }}
                                required
                            />
                            <TextField
                                label="Email"
                                size="small"
                                type="email"
                                value={recipient.email}
                                onChange={(e) => handleRecipientChange(index, "email", e.target.value)}
                                sx={{ flex: 1.5 }}
                                required
                            />
                            {inviteRecipients.length > 1 && (
                                <IconButton
                                    onClick={() => handleRemoveRecipient(index)}
                                    size="small"
                                    color="error"
                                >
                                    <DeleteIcon />
                                </IconButton>
                            )}
                        </Box>
                    ))}

                    <Button
                        startIcon={<AddIcon />}
                        onClick={handleAddRecipient}
                        size="small"
                        sx={{ mt: 1 }}
                    >
                        Add Another Recipient
                    </Button>
                </DialogContent>
                <DialogActions>
                    <Button onClick={handleCloseInviteModal}>Cancel</Button>
                    <Button
                        onClick={handleSendInvites}
                        variant="contained"
                        disabled={inviteSending}
                    >
                        {inviteSending ? "Sending..." : "Send Invites"}
                    </Button>
                </DialogActions>
            </Dialog>

            <Snackbar
                open={inviteSnackbar.open}
                autoHideDuration={6000}
                onClose={() => setInviteSnackbar({ ...inviteSnackbar, open: false })}
                anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
            >
                <Alert
                    onClose={() => setInviteSnackbar({ ...inviteSnackbar, open: false })}
                    severity={inviteSnackbar.severity}
                    sx={{ width: "100%" }}
                >
                    {inviteSnackbar.message}
                </Alert>
            </Snackbar>
        </Box>
    );
}
