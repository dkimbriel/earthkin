import { useState, useEffect } from "react";
import { useParams, useNavigate, useLocation } from "react-router-dom";
import {
    Box,
    Typography,
    Button,
    Paper,
    Chip,
    Card,
    CardContent,
    Collapse,
    IconButton,
    List,
    ListItem,
    ListItemText,
    Alert,
} from "@mui/material";
import Grid from "@mui/material/Grid";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import EditIcon from "@mui/icons-material/Edit";
import CancelIcon from "@mui/icons-material/Cancel";
import ExpandMoreIcon from "@mui/icons-material/ExpandMore";
import ExpandLessIcon from "@mui/icons-material/ExpandLess";
import EmailIcon from "@mui/icons-material/Email";
import DataTable from "../shared/DataTable";
import FormDialog from "../shared/FormDialog";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import { programEnrollmentsApi, paymentsApi, paymentPlansApi, enrollmentPaymentPlansApi } from "../../utils/api";

const getPaymentColumns = (onSendInvoice) => [
    {
        key: "payment_date",
        label: "Date",
        render: (row) => new Date(row.payment_date).toLocaleDateString(),
    },
    {
        key: "amount",
        label: "Amount",
        render: (row) => `$${parseFloat(row.amount).toFixed(2)}`,
    },
    {
        key: "payment_method",
        label: "Method",
        render: (row) => row.payment_method || "—",
    },
    {
        key: "status",
        label: "Status",
        render: (row) => (
            <Chip
                label={row.status}
                color={
                    row.status === "completed"
                        ? "success"
                        : row.status === "refunded"
                        ? "error"
                        : "default"
                }
                size="small"
            />
        ),
    },
    { key: "notes", label: "Notes", render: (row) => row.notes || "—" },
    {
        key: "actions",
        label: "Actions",
        render: (row) => (
            <Button
                size="small"
                startIcon={<EmailIcon />}
                onClick={(e) => {
                    e.stopPropagation();
                    onSendInvoice(row.id, row.status);
                }}
            >
                {row.status === "completed" ? "Send Receipt" : "Send Invoice"}
            </Button>
        ),
    },
];

export default function EnrollmentDetailPage() {
    const { id } = useParams();
    const navigate = useNavigate();
    const location = useLocation();
    const backTo = location.state?.from;
    const [enrollment, setEnrollment] = useState(null);
    const [loading, setLoading] = useState(true);
    const [showPaymentForm, setShowPaymentForm] = useState(false);
    const [showEditForm, setShowEditForm] = useState(false);
    const [deleteTarget, setDeleteTarget] = useState(null);
    const [showClasses, setShowClasses] = useState(false);
    const [showCancelForm, setShowCancelForm] = useState(false);
    const [invoiceMessage, setInvoiceMessage] = useState(null);
    const [showPlanForm, setShowPlanForm] = useState(false);
    const [paymentPlans, setPaymentPlans] = useState([]);

    const loadEnrollment = async () => {
        setLoading(true);
        try {
            const data = await programEnrollmentsApi.get(id);
            setEnrollment(data);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadEnrollment();
    }, [id]);

    const handleCreatePayment = async (formData) => {
        await paymentsApi.create({ ...formData, program_enrollment_id: id });
        loadEnrollment();
    };

    const openPlanForm = async () => {
        const plans = await paymentPlansApi.list(enrollment.program?.id, true);
        setPaymentPlans(plans);
        setShowPlanForm(true);
    };

    const handleCreatePlan = async (formData) => {
        await enrollmentPaymentPlansApi.create({
            program_enrollment_id: id,
            payment_plan_id: formData.payment_plan_id,
            total_amount: formData.total_amount || null,
            enrollment_fee: formData.enrollment_fee || 0,
            start_date: formData.start_date || null,
        });
        loadEnrollment();
    };

    const handleDeletePayment = async () => {
        if (deleteTarget) {
            await paymentsApi.delete(deleteTarget.id);
            setDeleteTarget(null);
            loadEnrollment();
        }
    };

    const handleUpdateEnrollment = async (formData) => {
        await programEnrollmentsApi.update(id, {
            status: formData.status,
            rate_per_class: parseFloat(formData.rate_per_class),
        });
        loadEnrollment();
    };

    const handleCancelEnrollment = async (formData) => {
        await programEnrollmentsApi.update(id, {
            status: "cancelled",
            cancelled_at: formData.cancelled_at,
        });
        loadEnrollment();
    };

    const handleSendInvoice = async (paymentId, status) => {
        try {
            await paymentsApi.sendInvoice(paymentId);
            const message = status === "completed"
                ? "Receipt sent successfully!"
                : "Invoice sent successfully!";
            setInvoiceMessage(message);
            setTimeout(() => setInvoiceMessage(null), 5000);
        } catch (err) {
            setInvoiceMessage(`Error: ${err.message}`);
        }
    };

    const enrollmentFormFields = [
        {
            name: "status",
            label: "Status",
            type: "select",
            required: true,
            defaultValue: enrollment?.status || "pending",
            options: [
                { value: "pending", label: "Pending" },
                { value: "confirmed", label: "Confirmed" },
                { value: "cancelled", label: "Cancelled" },
            ],
        },
        // Only show rate_per_class for legacy enrollments without payment plans
        ...(!enrollment?.enrollment_payment_plan ? [{
            name: "rate_per_class",
            label: "Rate per Class ($)",
            type: "number",
            required: true,
            defaultValue: enrollment?.rate_per_class || "",
        }] : []),
    ];

    const cancelFormFields = [
        {
            name: "cancelled_at",
            label: "Cancellation Date",
            type: "date",
            required: true,
            defaultValue: new Date().toISOString().split("T")[0],
        },
    ];

    const paymentFormFields = [
        {
            name: "amount",
            label: "Amount ($)",
            type: "number",
            required: true,
        },
        {
            name: "payment_date",
            label: "Payment Date",
            type: "date",
            required: true,
            defaultValue: new Date().toISOString().split("T")[0],
        },
        {
            name: "payment_method",
            label: "Payment Method",
            type: "select",
            options: [
                { value: "cash", label: "Cash" },
                { value: "check", label: "Check" },
                { value: "card", label: "Card" },
                { value: "venmo", label: "Venmo" },
                { value: "other", label: "Other" },
            ],
        },
        {
            name: "status",
            label: "Status",
            type: "select",
            required: true,
            defaultValue: "completed",
            options: [
                { value: "pending", label: "Pending" },
                { value: "completed", label: "Completed" },
                { value: "refunded", label: "Refunded" },
            ],
        },
        {
            name: "notes",
            label: "Notes",
            multiline: true,
            rows: 2,
        },
    ];

    if (loading) {
        return <Typography>Loading...</Typography>;
    }

    if (!enrollment) {
        return <Typography>Enrollment not found</Typography>;
    }

    const totalOwed = parseFloat(enrollment.total_owed) || 0;
    const totalPaid = parseFloat(enrollment.total_paid) || 0;
    const balanceDue = parseFloat(enrollment.balance_due) || 0;

    return (
        <Box>
            <Button
                startIcon={<ArrowBackIcon />}
                onClick={() =>
                    navigate(backTo || `/programs/${enrollment.program?.id}`)
                }
                sx={{ mb: 2 }}
            >
                {backTo?.includes("/families/")
                    ? "Back to Family"
                    : "Back to Program"}
            </Button>

            <Typography variant="h4" gutterBottom>
                Enrollment: {enrollment.child?.first_name}{" "}
                {enrollment.child?.last_name}
            </Typography>

            <Typography variant="h6" color="text.secondary" gutterBottom>
                {enrollment.program?.name}
            </Typography>

            <Box sx={{ display: "flex", gap: 1, mb: 3, alignItems: "center" }}>
                <Chip
                    label={enrollment.status}
                    color={
                        enrollment.status === "confirmed"
                            ? "success"
                            : enrollment.status === "cancelled"
                            ? "error"
                            : "default"
                    }
                />
                {enrollment.cancelled_at && (
                    <Chip
                        label={`Cancelled: ${new Date(enrollment.cancelled_at).toLocaleDateString()}`}
                        variant="outlined"
                        color="error"
                        size="small"
                    />
                )}
                {enrollment.enrollment_payment_plan?.payment_plan?.name && (
                    <Chip
                        label={enrollment.enrollment_payment_plan.payment_plan.name}
                        color="primary"
                        variant="outlined"
                    />
                )}
                <Button
                    size="small"
                    startIcon={<EditIcon />}
                    onClick={() => setShowEditForm(true)}
                >
                    Edit
                </Button>
                {enrollment.status !== "cancelled" && (
                    <Button
                        size="small"
                        color="error"
                        startIcon={<CancelIcon />}
                        onClick={() => setShowCancelForm(true)}
                    >
                        Cancel Enrollment
                    </Button>
                )}
            </Box>

            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid size={{ xs: 12, md: 4 }}>
                    <Card>
                        <CardContent>
                            <Box
                                sx={{
                                    display: "flex",
                                    justifyContent: "space-between",
                                    alignItems: "flex-start",
                                }}
                            >
                                <Box>
                                    <Typography
                                        color="text.secondary"
                                        gutterBottom
                                    >
                                        Total Owed
                                    </Typography>
                                    <Typography variant="h5">
                                        ${totalOwed.toFixed(2)}
                                    </Typography>
                                </Box>
                                {!enrollment.enrollment_payment_plan && enrollment.billable_classes?.length > 0 && (
                                    <IconButton
                                        size="small"
                                        onClick={() =>
                                            setShowClasses(!showClasses)
                                        }
                                        aria-label={
                                            showClasses
                                                ? "Hide classes"
                                                : "Show classes"
                                        }
                                    >
                                        {showClasses ? (
                                            <ExpandLessIcon />
                                        ) : (
                                            <ExpandMoreIcon />
                                        )}
                                    </IconButton>
                                )}
                            </Box>
                            {enrollment.enrollment_payment_plan ? (
                                <Typography
                                    variant="body2"
                                    color="text.secondary"
                                    sx={{ mt: 1 }}
                                >
                                    {enrollment.enrollment_payment_plan.payment_plan?.name}
                                    {enrollment.enrollment_payment_plan.enrollment_fee > 0 && (
                                        <> (+ ${parseFloat(enrollment.enrollment_payment_plan.enrollment_fee).toFixed(2)} enrollment fee)</>
                                    )}
                                </Typography>
                            ) : (
                                <>
                                    <Typography
                                        variant="body2"
                                        color="text.secondary"
                                        sx={{ mt: 1 }}
                                    >
                                        {enrollment.billable_classes?.length || 0} classes × ${parseFloat(enrollment.rate_per_class || 0).toFixed(2)}
                                    </Typography>
                                    <Button
                                        size="small"
                                        variant="outlined"
                                        sx={{ mt: 1 }}
                                        onClick={openPlanForm}
                                    >
                                        Add Payment Plan
                                    </Button>
                                </>
                            )}
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, md: 4 }}>
                    <Card style={{ height: "100%" }}>
                        <CardContent>
                            <Typography color="text.secondary" gutterBottom>
                                Total Paid
                            </Typography>
                            <Typography variant="h5" color="success.main">
                                ${totalPaid.toFixed(2)}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, md: 4 }}>
                    <Card style={{ height: "100%" }}>
                        <CardContent>
                            <Typography color="text.secondary" gutterBottom>
                                Balance Due
                            </Typography>
                            <Typography
                                variant="h5"
                                color={
                                    balanceDue > 0
                                        ? "warning.main"
                                        : "success.main"
                                }
                            >
                                ${balanceDue.toFixed(2)}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            <Paper sx={{ p: 3 }}>
                <PageHeader
                    title="Payments"
                    onAdd={() => setShowPaymentForm(true)}
                    addLabel="Record Payment"
                />
                {invoiceMessage && (
                    <Alert
                        severity={invoiceMessage.startsWith("Error") ? "error" : "success"}
                        sx={{ mb: 2 }}
                        onClose={() => setInvoiceMessage(null)}
                    >
                        {invoiceMessage}
                    </Alert>
                )}
                <DataTable
                    columns={getPaymentColumns(handleSendInvoice)}
                    data={enrollment.payments}
                    loading={false}
                    onDelete={setDeleteTarget}
                    emptyMessage="No payments recorded yet."
                />
            </Paper>

            <FormDialog
                open={showPaymentForm}
                onClose={() => setShowPaymentForm(false)}
                onSubmit={handleCreatePayment}
                title="Record Payment"
                fields={paymentFormFields}
            />

            {showPlanForm && (
                <FormDialog
                    open={showPlanForm}
                    onClose={() => setShowPlanForm(false)}
                    onSubmit={handleCreatePlan}
                    title="Add Payment Plan"
                    fields={[
                        {
                            name: "payment_plan_id",
                            label: "Payment Plan",
                            type: "select",
                            required: true,
                            options: paymentPlans.map((p) => ({
                                value: p.id,
                                label: `${p.name} — $${parseFloat(p.total_amount).toFixed(2)} (${p.installment_count} payments)`,
                            })),
                        },
                        {
                            name: "total_amount",
                            label: "Total Tuition ($)",
                            type: "number",
                            helperText: "Leave blank to use the plan's standard amount.",
                        },
                        {
                            name: "enrollment_fee",
                            label: "Enrollment Fee ($)",
                            type: "number",
                            defaultValue: "0",
                        },
                        {
                            name: "start_date",
                            label: "First Payment Due",
                            type: "date",
                            defaultValue: enrollment.program?.start_date || "",
                            helperText: "Defaults to the program start date — monthly payments fall on this day of the month.",
                        },
                    ]}
                />
            )}

            <FormDialog
                open={showEditForm}
                onClose={() => setShowEditForm(false)}
                onSubmit={handleUpdateEnrollment}
                title="Edit Enrollment"
                fields={enrollmentFormFields}
                submitLabel="Save"
            />

            <FormDialog
                open={showCancelForm}
                onClose={() => setShowCancelForm(false)}
                onSubmit={handleCancelEnrollment}
                title="Cancel Enrollment"
                fields={cancelFormFields}
                submitLabel="Cancel Enrollment"
            />

            <ConfirmDialog
                open={!!deleteTarget}
                onClose={() => setDeleteTarget(null)}
                onConfirm={handleDeletePayment}
                title="Delete Payment"
                message={`Are you sure you want to delete this $${parseFloat(
                    deleteTarget?.amount || 0
                ).toFixed(2)} payment?`}
            />
        </Box>
    );
}
