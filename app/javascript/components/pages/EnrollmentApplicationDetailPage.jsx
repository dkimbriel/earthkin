import { useState, useEffect } from "react";
import { useParams, useNavigate, useSearchParams } from "react-router-dom";
import {
    Box,
    Typography,
    Button,
    Paper,
    Grid,
    Chip,
    Divider,
    Alert,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    MenuItem,
    Snackbar,
    Tooltip,
    Tabs,
    Tab,
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import CheckCircleIcon from "@mui/icons-material/CheckCircle";
import CancelIcon from "@mui/icons-material/Cancel";
import EventIcon from "@mui/icons-material/Event";
import PaymentIcon from "@mui/icons-material/Payment";
import EditIcon from "@mui/icons-material/Edit";
import PersonIcon from "@mui/icons-material/Person";
import DescriptionIcon from "@mui/icons-material/Description";
import EmailIcon from "@mui/icons-material/Email";
import VisibilityIcon from "@mui/icons-material/Visibility";
import VisibilityOffIcon from "@mui/icons-material/VisibilityOff";
import IconButton from "@mui/material/IconButton";
import {
    enrollmentApplicationsApi,
    eventsApi,
    locationsApi,
} from "../../utils/api";
import PaymentPlanSelector from "../enrollment/PaymentPlanSelector";
import EmailTimeline from "../enrollment/EmailTimeline";
import ComposeEmailDialog from "../shared/ComposeEmailDialog";
import ActionButtonWithEmail from "../enrollment/ActionButtonWithEmail";

const formatStatusLabel = (status) => {
    return status
        .replace(/_/g, " ")
        .split(" ")
        .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
        .join(" ");
};

function TabPanel({ children, value, index, ...other }) {
    return (
        <div
            role="tabpanel"
            hidden={value !== index}
            id={`application-tabpanel-${index}`}
            aria-labelledby={`application-tab-${index}`}
            {...other}
        >
            {value === index && <Box sx={{ py: 3 }}>{children}</Box>}
        </div>
    );
}

const TAB_NAMES = ["overview", "application", "communications", "payment-plan"];

export default function EnrollmentApplicationDetailPage() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [searchParams, setSearchParams] = useSearchParams();
    const [application, setApplication] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [emailNotification, setEmailNotification] = useState(null);
    const [composeDraft, setComposeDraft] = useState(null);
    const [showDob, setShowDob] = useState(false);

    const tabParam = searchParams.get("tab");
    const activeTab = TAB_NAMES.indexOf(tabParam) !== -1 ? TAB_NAMES.indexOf(tabParam) : 0;

    // Dialog states
    const [showMeetingDialog, setShowMeetingDialog] = useState(false);
    const [showCompleteMeetingDialog, setShowCompleteMeetingDialog] =
        useState(false);
    const [showFeeDialog, setShowFeeDialog] = useState(false);
    const [showEmailEditDialog, setShowEmailEditDialog] = useState(false);
    const [showDeclineDialog, setShowDeclineDialog] = useState(false);
    const [showCustomFeesDialog, setShowCustomFeesDialog] = useState(false);
    const [locations, setLocations] = useState([]);
    const [editedEmail, setEditedEmail] = useState("");
    const [declineNotes, setDeclineNotes] = useState("");
    const [completeMeetingNotes, setCompleteMeetingNotes] = useState("");
    const [customFeesForm, setCustomFeesForm] = useState({
        customEnrollmentFee: "",
        customTuitionAmount: "",
    });

    // Meeting invite form - 3 proposed dates for parent to choose from
    const [meetingForm, setMeetingForm] = useState({
        location_id: "",
        proposed_date_1: "",
        proposed_date_2: "",
        proposed_date_3: "",
        notes: "",
    });

    // Fee payment form
    const [feeForm, setFeeForm] = useState({
        payment_plan_id: "",
        payment_method: "venmo",
        payment_date: new Date().toISOString().split("T")[0],
        notes: "",
    });

    useEffect(() => {
        loadApplication();
        loadLocations();
    }, [id]);

    const loadApplication = async () => {
        setLoading(true);
        setError(null);
        try {
            const data = await enrollmentApplicationsApi.get(id);
            setApplication(data);
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    // Helper to format datetime-local value from ISO string
    const formatDateTimeLocal = (isoString) => {
        if (!isoString) return "";
        const date = new Date(isoString);
        // Format as YYYY-MM-DDTHH:MM for datetime-local input
        return date.toISOString().slice(0, 16);
    };

    // Helper to get tomorrow at 8 AM as datetime-local string
    const getTomorrowAt8AM = () => {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(8, 0, 0, 0);
        const year = tomorrow.getFullYear();
        const month = String(tomorrow.getMonth() + 1).padStart(2, "0");
        const day = String(tomorrow.getDate()).padStart(2, "0");
        return `${year}-${month}-${day}T08:00`;
    };

    // Open meeting dialog, prepopulating if there's an existing pending event
    const openMeetingDialog = () => {
        const pendingEvent = application?.events?.find(
            (e) => e.event_type === "meet_and_greet" && e.status === "pending_selection"
        );

        if (pendingEvent) {
            const proposedDates = pendingEvent.proposed_dates || [];
            setMeetingForm({
                location_id: pendingEvent.location_id || "",
                proposed_date_1: formatDateTimeLocal(proposedDates[0]),
                proposed_date_2: formatDateTimeLocal(proposedDates[1]),
                proposed_date_3: formatDateTimeLocal(proposedDates[2]),
                notes: pendingEvent.notes || "",
            });
        } else {
            setMeetingForm({
                location_id: "",
                proposed_date_1: "",
                proposed_date_2: "",
                proposed_date_3: "",
                notes: "",
            });
        }
        setShowMeetingDialog(true);
    };

    // Check if there's already a pending meeting invite
    const hasPendingMeetingInvite = application?.events?.some(
        (e) => e.event_type === "meet_and_greet" && e.status === "pending_selection"
    );

    const loadLocations = async () => {
        try {
            const data = await locationsApi.list();
            setLocations(data);
        } catch (err) {
            console.error("Failed to load locations:", err);
        }
    };

    const handleMarkReviewed = async () => {
        try {
            await enrollmentApplicationsApi.markReviewed(id);
            loadApplication();
        } catch (err) {
            setError(err.message);
        }
    };

    const handleSendMeetingInvite = async () => {
        try {
            // Collect non-empty proposed dates
            const proposedDates = [
                meetingForm.proposed_date_1,
                meetingForm.proposed_date_2,
                meetingForm.proposed_date_3,
            ].filter(Boolean);

            if (proposedDates.length < 2) {
                setError("Please provide at least 2 date options");
                return;
            }

            await enrollmentApplicationsApi.sendMeetingInvite(id, {
                locationId: meetingForm.location_id,
                proposedDates: proposedDates,
                notes: meetingForm.notes,
            });
            setShowMeetingDialog(false);
            setMeetingForm({
                location_id: "",
                proposed_date_1: "",
                proposed_date_2: "",
                proposed_date_3: "",
                notes: "",
            });
            setEmailNotification("Meeting invite email sent to parent with date options");
            loadApplication();
        } catch (err) {
            setError(err.message);
        }
    };

    const handleCompleteMeeting = async () => {
        try {
            await enrollmentApplicationsApi.completeMeeting(
                id,
                completeMeetingNotes,
            );
            setShowCompleteMeetingDialog(false);
            setCompleteMeetingNotes("");
            setEmailNotification("Meeting completed. Enrollment fee request email sent to parent.");
            loadApplication();
        } catch (err) {
            setError(err.message);
        }
    };

    const handleRequestFee = async () => {
        try {
            await enrollmentApplicationsApi.requestFee(id);
            setEmailNotification("Enrollment fee request email sent to parent");
            loadApplication();
        } catch (err) {
            setError(err.message);
        }
    };

    const openFeeDialog = () => {
        setFeeForm((prev) => ({
            ...prev,
            payment_plan_id: application.selected_payment_plan?.id || "",
        }));
        setShowFeeDialog(true);
    };

    const handleProcessFeePayment = async () => {
        try {
            await enrollmentApplicationsApi.processFeePayment(id, feeForm);
            setShowFeeDialog(false);
            setFeeForm({
                payment_plan_id: "",
                payment_method: "venmo",
                payment_date: new Date().toISOString().split("T")[0],
                notes: "",
            });
            loadApplication();
        } catch (err) {
            setError(err.message);
        }
    };

    const handleSendEnrollmentForms = async () => {
        try {
            await enrollmentApplicationsApi.sendEnrollmentForms(id);
            setEmailNotification("Enrollment forms sent to parent");
            loadApplication();
        } catch (err) {
            setError(err.message);
        }
    };

    const handleConfirmEnrollment = async () => {
        try {
            await enrollmentApplicationsApi.confirmEnrollment(id);
            setEmailNotification("Enrollment confirmed! Welcome email sent to family.");
            loadApplication();
        } catch (err) {
            setError(err.message);
        }
    };

    const handleDecline = async () => {
        try {
            await enrollmentApplicationsApi.decline(id, declineNotes);
            setShowDeclineDialog(false);
            setDeclineNotes("");
            loadApplication();
        } catch (err) {
            setError(err.message);
        }
    };

    const handleEditEmail = () => {
        setEditedEmail(application.parent_email);
        setShowEmailEditDialog(true);
    };

    const handleSaveEmail = async () => {
        try {
            await enrollmentApplicationsApi.updateParentEmail(id, editedEmail);
            setEmailNotification("Email address updated successfully");
            setShowEmailEditDialog(false);
            loadApplication();
        } catch (err) {
            setError(err.message);
        }
    };

    // Opens the manual composer prefilled with the workflow email (tokens
    // already resolved for this family) so it can be edited before sending.
    const handleSendEmail = async (emailType) => {
        try {
            const draft = await enrollmentApplicationsApi.emailDraft(id, emailType);
            setComposeDraft(draft);
        } catch (err) {
            setError(err.message);
        }
    };

    const handleEditCustomFees = () => {
        setCustomFeesForm({
            customEnrollmentFee: application.custom_enrollment_fee || "",
            customTuitionAmount: application.custom_tuition_amount || "",
        });
        setShowCustomFeesDialog(true);
    };

    const handleSaveCustomFees = async () => {
        try {
            await enrollmentApplicationsApi.updateCustomFees(id, {
                customEnrollmentFee: customFeesForm.customEnrollmentFee || null,
                customTuitionAmount: customFeesForm.customTuitionAmount || null,
            });
            setEmailNotification("Custom fees updated successfully");
            setShowCustomFeesDialog(false);
            loadApplication();
        } catch (err) {
            setError(err.message);
        }
    };

    if (loading) return <Typography>Loading...</Typography>;
    if (!application) return <Typography>Application not found</Typography>;

    // Single source of truth for the family's payment plan. Once the fee is
    // recorded, the enrollment's locked-in plan is authoritative; before that,
    // it's the plan the parent tentatively selected. These can differ (parent
    // picks one, admin records another), so we must never treat both as
    // "selected" — otherwise two plans light up at once.
    const lockedPlan =
        application.program_enrollment?.enrollment_payment_plan?.payment_plan;
    const selectedPlan = lockedPlan || application.selected_payment_plan;
    const goToPaymentPlanTab = () => setSearchParams({ tab: "payment-plan" });

    // Find meet and greet event - prefer scheduled/confirmed over pending_selection
    const meetAndGreetEvents =
        application.events?.filter((e) => e.event_type === "meet_and_greet") ||
        [];
    const meetAndGreet =
        meetAndGreetEvents.find((e) => e.status !== "pending_selection") ||
        meetAndGreetEvents.find((e) => e.status === "pending_selection");

    return (
        <Box>
            <Button
                startIcon={<ArrowBackIcon />}
                onClick={() => navigate("/enrollment-applications")}
                sx={{ mb: 2 }}
            >
                Back to Applications
            </Button>

            {error && (
                <Alert
                    severity="error"
                    sx={{ mb: 2 }}
                    onClose={() => setError(null)}
                >
                    {error}
                </Alert>
            )}

            <Paper sx={{ p: 3 }}>
                {/* Header */}
                <Box
                    sx={{
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        mb: 2,
                    }}
                >
                    <Box>
                        <Typography variant="h4">
                            {application.full_child_name}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            {application.program?.name} &bull; Applied{" "}
                            {new Date(
                                application.created_at,
                            ).toLocaleDateString()}
                        </Typography>
                    </Box>
                    <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
                        <Chip
                            label={formatStatusLabel(application.status)}
                            color="primary"
                        />
                        {(() => {
                            if (!selectedPlan) return null;
                            // Pull the full plan (with installment details) from the
                            // program's plans; selectedPlan itself may be a lighter object.
                            const fullPlan =
                                application.payment_plans?.find((p) => p.id === selectedPlan.id) ||
                                selectedPlan;
                            const total = application.custom_tuition_amount
                                ? parseFloat(application.custom_tuition_amount)
                                : parseFloat(fullPlan.total_amount);
                            const count = fullPlan.installment_count;
                            const perPayment =
                                count && !Number.isNaN(total) ? (total / count).toFixed(2) : null;
                            const detail = count && perPayment ? ` · ${count} × $${perPayment}` : "";
                            const locked = Boolean(lockedPlan);
                            return (
                                <Tooltip title={`${locked ? "Enrolled on" : "Parent selected"} this plan — view details`}>
                                    <Chip
                                        icon={<PaymentIcon />}
                                        label={`${fullPlan.name}${detail}`}
                                        color="success"
                                        variant={locked ? "filled" : "outlined"}
                                        onClick={goToPaymentPlanTab}
                                        clickable
                                    />
                                </Tooltip>
                            );
                        })()}
                        {!["declined", "enrolled"].includes(
                            application.status,
                        ) && (
                            <Button
                                variant="outlined"
                                color="error"
                                size="small"
                                startIcon={<CancelIcon />}
                                onClick={() => setShowDeclineDialog(true)}
                            >
                                Decline Application
                            </Button>
                        )}
                    </Box>
                </Box>

                {/* Action Buttons - Always visible */}
                <Box sx={{ mb: 2, display: "flex", gap: 2, flexWrap: "wrap" }}>
                    {application.status === "submitted" && (
                        <ActionButtonWithEmail
                            variant="contained"
                            startIcon={<CheckCircleIcon />}
                            onClick={handleMarkReviewed}
                            emailDescription="No email will be sent. Mark as reviewed to proceed with scheduling."
                        >
                            Mark as Reviewed
                        </ActionButtonWithEmail>
                    )}

                    {application.status === "reviewed" && (
                        <ActionButtonWithEmail
                            variant="contained"
                            startIcon={<EventIcon />}
                            onClick={openMeetingDialog}
                            emailDescription="Parent will receive an email with date options to choose from"
                        >
                            {hasPendingMeetingInvite ? "Resend Meeting Invite" : "Send Meeting Invite"}
                        </ActionButtonWithEmail>
                    )}

                    {application.status === "meeting_completed" && (
                        <ActionButtonWithEmail
                            variant="contained"
                            startIcon={<PaymentIcon />}
                            onClick={handleRequestFee}
                            emailDescription="Parent will receive payment instructions and enrollment fee details"
                        >
                            Request Enrollment Fee
                        </ActionButtonWithEmail>
                    )}

                    {application.status === "fee_requested" && (
                        <ActionButtonWithEmail
                            variant="outlined"
                            startIcon={<EmailIcon />}
                            onClick={() => handleSendEmail("enrollment_fee_request")}
                            emailDescription="Resend fee request email with payment instructions"
                        >
                            Resend Fee Request Email
                        </ActionButtonWithEmail>
                    )}

                    {["submitted", "reviewed", "meeting_scheduled", "meeting_completed", "fee_requested"].includes(
                        application.status,
                    ) && (
                        <Button
                            variant="contained"
                            startIcon={<PaymentIcon />}
                            onClick={openFeeDialog}
                            color="success"
                        >
                            Select Payment Plan & Record Payment
                        </Button>
                    )}

                    {application.status === "fee_paid" && (
                        <ActionButtonWithEmail
                            variant="contained"
                            startIcon={<DescriptionIcon />}
                            onClick={handleSendEnrollmentForms}
                            emailDescription="Parent will receive enrollment forms for signing"
                        >
                            Send Enrollment Forms
                        </ActionButtonWithEmail>
                    )}

                    {application.status === "signing_docs" && (
                        <Button
                            variant="contained"
                            color="success"
                            startIcon={<CheckCircleIcon />}
                            onClick={handleConfirmEnrollment}
                        >
                            Confirm Enrollment
                        </Button>
                    )}
                </Box>

                {/* Parent's payment plan selection - visible regardless of tab */}
                {application.selected_payment_plan &&
                    !["fee_paid", "signing_docs", "enrolled"].includes(application.status) && (
                        <Alert
                            severity="success"
                            icon={<CheckCircleIcon />}
                            sx={{ mb: 2 }}
                            action={
                                <Button
                                    color="inherit"
                                    size="small"
                                    startIcon={<PaymentIcon />}
                                    onClick={openFeeDialog}
                                >
                                    Record Payment
                                </Button>
                            }
                        >
                            <Typography variant="body2" fontWeight="medium">
                                Parent selected the {application.selected_payment_plan.name} plan
                            </Typography>
                            <Typography variant="body2">
                                Record their enrollment fee payment to lock in this plan and create the enrollment.
                            </Typography>
                        </Alert>
                    )}

                <Divider />

                {/* Tabs */}
                <Tabs
                    value={activeTab}
                    onChange={(e, newValue) => {
                        if (newValue === 0) {
                            setSearchParams({});
                        } else {
                            setSearchParams({ tab: TAB_NAMES[newValue] });
                        }
                    }}
                    sx={{ borderBottom: 1, borderColor: "divider" }}
                >
                    <Tab
                        icon={<PersonIcon />}
                        iconPosition="start"
                        label="Overview"
                        sx={{ textTransform: "none" }}
                    />
                    <Tab
                        icon={<DescriptionIcon />}
                        iconPosition="start"
                        label="Application"
                        sx={{ textTransform: "none" }}
                    />
                    <Tab
                        icon={<EmailIcon />}
                        iconPosition="start"
                        label="Communications"
                        sx={{ textTransform: "none" }}
                    />
                    <Tab
                        icon={<PaymentIcon />}
                        iconPosition="start"
                        label="Payment Plan"
                        sx={{ textTransform: "none" }}
                    />
                </Tabs>

                {/* Tab: Overview */}
                <TabPanel value={activeTab} index={0}>
                    <Box sx={{ display: "flex", flexDirection: { xs: "column", md: "row" }, gap: 6 }}>
                        {/* Left Column - Parent Info */}
                        <Box sx={{ flex: 1 }}>
                            <Typography variant="h6" gutterBottom>
                                Parent/Guardian Information
                            </Typography>

                            {/* Parent 1 */}
                            <Box sx={{ mb: 3 }}>
                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                    Parent/Guardian 1
                                </Typography>
                                <Box sx={{ display: "flex", flexDirection: "column", gap: 0.5 }}>
                                    <Typography>{application.full_parent_name}</Typography>
                                    <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
                                        <Typography>{application.parent_email}</Typography>
                                        <IconButton size="small" onClick={handleEditEmail}>
                                            <EditIcon fontSize="small" />
                                        </IconButton>
                                    </Box>
                                    <Typography>{application.parent_phone || "—"}</Typography>
                                </Box>
                            </Box>

                            {/* Parent 2 */}
                            {application.parent2_first_name && (
                                <Box>
                                    <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                        Parent/Guardian 2
                                    </Typography>
                                    <Box sx={{ display: "flex", flexDirection: "column", gap: 0.5 }}>
                                        <Typography>
                                            {application.parent2_first_name} {application.parent2_last_name}
                                        </Typography>
                                        <Typography>{application.parent2_email || "—"}</Typography>
                                        <Typography>{application.parent2_phone || "—"}</Typography>
                                    </Box>
                                </Box>
                            )}
                        </Box>

                        {/* Right Column - Child Info */}
                        <Box sx={{ flex: 1 }}>
                            <Typography variant="h6" gutterBottom>
                                Child Information
                            </Typography>
                            <Box sx={{ display: "flex", flexDirection: "column", gap: 0.5 }}>
                                <Typography>{application.full_child_name}</Typography>
                                {application.child_date_of_birth && (
                                    <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
                                        <Typography>
                                            Born {showDob
                                                ? new Date(application.child_date_of_birth).toLocaleDateString()
                                                : "**/**/****"}
                                        </Typography>
                                        <IconButton
                                            size="small"
                                            onClick={() => setShowDob(!showDob)}
                                            sx={{ ml: 0.5 }}
                                        >
                                            {showDob ? <VisibilityOffIcon fontSize="small" /> : <VisibilityIcon fontSize="small" />}
                                        </IconButton>
                                    </Box>
                                )}
                                {application.child_race_ethnicity && (
                                    <Typography color="text.secondary">
                                        {application.child_race_ethnicity}
                                    </Typography>
                                )}
                            </Box>
                        </Box>
                    </Box>

                    {meetAndGreet && (
                        <>
                            <Divider sx={{ my: 3 }} />
                            <Typography variant="h6" gutterBottom>
                                Meet & Greet
                            </Typography>
                            <Box
                                sx={{
                                    display: "flex",
                                    flexDirection: "column",
                                    gap: 0.5,
                                }}
                            >
                                {meetAndGreet.status === "pending_selection" ? (
                                    <>
                                        <Typography>
                                            <strong>Status:</strong>{" "}
                                            <Chip
                                                label="Awaiting Parent Selection"
                                                color="warning"
                                                size="small"
                                            />
                                        </Typography>
                                        <Typography>
                                            <strong>Location:</strong>{" "}
                                            {meetAndGreet.location?.name || "—"}
                                        </Typography>
                                        <Typography
                                            variant="subtitle2"
                                            sx={{ mt: 1 }}
                                        >
                                            Proposed Dates:
                                        </Typography>
                                        <Box
                                            component="ul"
                                            sx={{ m: 0, pl: 3 }}
                                        >
                                            {meetAndGreet.proposed_dates?.map(
                                                (date, i) => (
                                                    <Typography
                                                        component="li"
                                                        key={i}
                                                    >
                                                        {new Date(
                                                            date,
                                                        ).toLocaleString(
                                                            "en-US",
                                                            {
                                                                weekday: "long",
                                                                month: "long",
                                                                day: "numeric",
                                                                hour: "numeric",
                                                                minute: "2-digit",
                                                                timeZone:
                                                                    "America/New_York",
                                                            },
                                                        )}{" "}
                                                        ET
                                                    </Typography>
                                                ),
                                            )}
                                        </Box>
                                    </>
                                ) : (
                                    <>
                                        <Typography>
                                            <strong>Scheduled:</strong>{" "}
                                            {new Date(
                                                meetAndGreet.scheduled_at,
                                            ).toLocaleString("en-US", {
                                                weekday: "long",
                                                month: "long",
                                                day: "numeric",
                                                year: "numeric",
                                                hour: "numeric",
                                                minute: "2-digit",
                                                timeZone: "America/New_York",
                                            })}{" "}
                                            ET
                                        </Typography>
                                        <Typography>
                                            <strong>Location:</strong>{" "}
                                            {meetAndGreet.location?.name || "—"}
                                        </Typography>
                                        <Typography>
                                            <strong>Status:</strong>{" "}
                                            <Chip
                                                label={formatStatusLabel(
                                                    meetAndGreet.status,
                                                )}
                                                color={
                                                    meetAndGreet.status ===
                                                    "completed"
                                                        ? "success"
                                                        : "primary"
                                                }
                                                size="small"
                                            />
                                        </Typography>
                                        {application.status === "meeting_scheduled" && (
                                            <Button
                                                variant="contained"
                                                startIcon={<CheckCircleIcon />}
                                                onClick={() => setShowCompleteMeetingDialog(true)}
                                                sx={{ mt: 2, alignSelf: "flex-start" }}
                                            >
                                                Meet & Greet Complete
                                            </Button>
                                        )}
                                    </>
                                )}
                            </Box>
                        </>
                    )}
                </TabPanel>

                {/* Tab: Application Details */}
                <TabPanel value={activeTab} index={1}>
                    <Box
                        sx={{
                            display: "flex",
                            flexDirection: "column",
                            gap: 3,
                        }}
                    >
                        {application.referral_source && (
                            <Box>
                                <Typography
                                    variant="subtitle2"
                                    color="text.secondary"
                                >
                                    How did you hear about us?
                                </Typography>
                                <Typography>
                                    {application.referral_source}
                                </Typography>
                            </Box>
                        )}

                        {application.is_local && (
                            <Box>
                                <Typography
                                    variant="subtitle2"
                                    color="text.secondary"
                                >
                                    Local to Swansboro neighborhood or southside Richmond?
                                </Typography>
                                <Typography>
                                    {application.is_local === 'yes' ? 'Yes' :
                                     application.is_local === 'no' ? 'No' :
                                     "Not sure"}
                                    {application.local_area && ` (${application.local_area})`}
                                </Typography>
                            </Box>
                        )}

                        {application.why_interested && (
                            <Box>
                                <Typography
                                    variant="subtitle2"
                                    color="text.secondary"
                                >
                                    What draws you to a nature-based preschool program?
                                </Typography>
                                <Typography sx={{ whiteSpace: "pre-wrap" }}>
                                    {application.why_interested}
                                </Typography>
                            </Box>
                        )}

                        {application.child_description && (
                            <Box>
                                <Typography
                                    variant="subtitle2"
                                    color="text.secondary"
                                >
                                    About the child (temperament, interests, outdoor activity level, special needs)
                                </Typography>
                                <Typography sx={{ whiteSpace: "pre-wrap" }}>
                                    {application.child_description}
                                </Typography>
                            </Box>
                        )}

                        {application.special_needs && (
                            <Box>
                                <Typography
                                    variant="subtitle2"
                                    color="text.secondary"
                                >
                                    Special needs or accommodations
                                </Typography>
                                <Typography sx={{ whiteSpace: "pre-wrap" }}>
                                    {application.special_needs}
                                </Typography>
                            </Box>
                        )}

                        {application.dietary_restrictions && (
                            <Box>
                                <Typography
                                    variant="subtitle2"
                                    color="text.secondary"
                                >
                                    Dietary restrictions
                                </Typography>
                                <Typography>
                                    {application.dietary_restrictions}
                                </Typography>
                            </Box>
                        )}

                        {!application.why_interested &&
                            !application.child_description &&
                            !application.special_needs &&
                            !application.dietary_restrictions && (
                                <Typography color="text.secondary">
                                    No additional application details provided.
                                </Typography>
                            )}
                    </Box>

                    {/* Agreements Section */}
                    {application.agreements && Object.keys(application.agreements).length > 0 && (
                        <>
                            <Divider sx={{ my: 3 }} />
                            <Typography variant="h6" gutterBottom>
                                Agreements Acknowledged
                            </Typography>
                            <Box sx={{ display: "flex", flexDirection: "column", gap: 0.5 }}>
                                {application.agreements.program_details && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Program details (schedule, location, tuition)
                                    </Typography>
                                )}
                                {application.agreements.enrollment_fee && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Enrollment fee structure
                                    </Typography>
                                )}
                                {application.agreements.sibling_discount && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Sibling discount policy
                                    </Typography>
                                )}
                                {application.agreements.payment_terms && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Payment terms
                                    </Typography>
                                )}
                                {application.agreements.outdoor_programming && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Outdoor programming acknowledgment
                                    </Typography>
                                )}
                                {application.agreements.weather_policy && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Weather/safety cancellation policy
                                    </Typography>
                                )}
                                {application.agreements.emergent_curriculum && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Emergent curriculum approach
                                    </Typography>
                                )}
                                {application.agreements.follow_instructions && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Follow instructions requirement
                                    </Typography>
                                )}
                                {application.agreements.toilet_proficiency && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Toilet proficiency requirement
                                    </Typography>
                                )}
                                {application.agreements.meet_and_greet && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Meet-and-greet attendance
                                    </Typography>
                                )}
                                {application.agreements.application_status && (
                                    <Typography variant="body2" color="success.main">
                                        ✓ Application status understanding
                                    </Typography>
                                )}
                            </Box>
                        </>
                    )}

                    {application.admin_notes && (
                        <>
                            <Divider sx={{ my: 3 }} />
                            <Typography variant="h6" gutterBottom>
                                Admin Notes
                            </Typography>
                            <Typography
                                sx={{
                                    whiteSpace: "pre-wrap",
                                    bgcolor: "grey.50",
                                    p: 2,
                                    borderRadius: 1,
                                }}
                            >
                                {application.admin_notes}
                            </Typography>
                        </>
                    )}
                </TabPanel>

                {/* Tab: Communications */}
                <TabPanel value={activeTab} index={2}>
                    <EmailTimeline
                        emails={application.emails || []}
                        application={application}
                        onSendEmail={handleSendEmail}
                    />
                    {composeDraft && (
                        <ComposeEmailDialog
                            open
                            onClose={() => setComposeDraft(null)}
                            initial={composeDraft}
                            showPickers={false}
                            onSaved={() => {
                                setEmailNotification("Draft saved — it's under Emails > Drafts");
                                loadApplication();
                            }}
                            onSent={() => {
                                setEmailNotification("Email sent to parent");
                                loadApplication();
                            }}
                        />
                    )}
                </TabPanel>

                {/* Tab: Payment Plan */}
                <TabPanel value={activeTab} index={3}>
                    <Box sx={{ display: "flex", flexDirection: "column", gap: 3 }}>
                        {/* Tuition Summary */}
                        <Box>
                            <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 1 }}>
                                <Typography variant="h6">
                                    Tuition Summary
                                </Typography>
                                <Button
                                    size="small"
                                    startIcon={<EditIcon />}
                                    onClick={handleEditCustomFees}
                                >
                                    Edit Fees
                                </Button>
                            </Box>
                            <Grid container spacing={3}>
                                <Grid item xs={12} sm={6}>
                                    <Paper variant="outlined" sx={{ p: 2 }}>
                                        <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 1, mb: 0.5 }}>
                                            <Typography variant="subtitle2" color="text.secondary">
                                                Enrollment Fee
                                            </Typography>
                                            {application.custom_enrollment_fee && (
                                                <Chip label="Custom" size="small" color="warning" sx={{ flexShrink: 0 }} />
                                            )}
                                        </Box>
                                        <Typography variant="h5">
                                            ${parseFloat(application.effective_enrollment_fee || application.program?.enrollment_fee || 150).toFixed(2)}
                                        </Typography>
                                        {application.custom_enrollment_fee && (
                                            <Typography variant="caption" color="text.secondary">
                                                Program default: ${parseFloat(application.program?.enrollment_fee || 150).toFixed(2)}
                                            </Typography>
                                        )}
                                    </Paper>
                                </Grid>
                                <Grid item xs={12} sm={6}>
                                    <Paper variant="outlined" sx={{ p: 2 }}>
                                        <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 1, mb: 0.5 }}>
                                            <Typography variant="subtitle2" color="text.secondary">
                                                Annual Tuition
                                            </Typography>
                                            {application.custom_tuition_amount && (
                                                <Chip label="Custom" size="small" color="warning" sx={{ flexShrink: 0 }} />
                                            )}
                                        </Box>
                                        <Typography variant="h5">
                                            {application.effective_tuition_amount
                                                ? `$${parseFloat(application.effective_tuition_amount).toFixed(2)}`
                                                : "—"}
                                        </Typography>
                                        {application.custom_tuition_amount && application.payment_plans?.[0]?.total_amount && (
                                            <Typography variant="caption" color="text.secondary">
                                                Plan default: ${parseFloat(application.payment_plans[0].total_amount).toFixed(2)}
                                            </Typography>
                                        )}
                                    </Paper>
                                </Grid>
                            </Grid>
                        </Box>

                        <Divider />

                        {/* Payment Plan Options */}
                        <Box>
                            <Typography variant="h6" gutterBottom>
                                Payment Plan Options
                            </Typography>

                            {/* Selection Status Message */}
                            {(() => {
                                if (selectedPlan) {
                                    return null; // Selected plan will be highlighted below
                                } else if (application.status === "fee_requested") {
                                    return (
                                        <Alert severity="warning" sx={{ mb: 2 }}>
                                            <Typography variant="body2" fontWeight="medium">
                                                Awaiting Parent Selection
                                            </Typography>
                                            <Typography variant="body2">
                                                The parent has been sent a link to select their preferred payment plan.
                                            </Typography>
                                        </Alert>
                                    );
                                } else if (["submitted", "reviewed", "meeting_scheduled", "meeting_completed"].includes(application.status)) {
                                    return (
                                        <Alert severity="info" sx={{ mb: 2 }}>
                                            <Typography variant="body2" fontWeight="medium">
                                                No Payment Plan Selected Yet
                                            </Typography>
                                            <Typography variant="body2">
                                                The parent will select a payment plan after the meet & greet, when the enrollment fee is requested.
                                            </Typography>
                                        </Alert>
                                    );
                                }
                                return null;
                            })()}

                            {application.payment_plans && application.payment_plans.length > 0 ? (
                                <Box sx={{ display: "flex", flexDirection: "column", gap: 2 }}>
                                    {application.payment_plans.map((plan) => {
                                        const isSelected = selectedPlan?.id === plan.id;

                                        // Calculate effective amounts based on custom tuition
                                        const hasCustomTuition = !!application.custom_tuition_amount;
                                        const effectiveTotalAmount = hasCustomTuition
                                            ? parseFloat(application.custom_tuition_amount)
                                            : parseFloat(plan.total_amount);
                                        const effectiveInstallmentAmount = effectiveTotalAmount / plan.installment_count;

                                        return (
                                            <Paper
                                                key={plan.id}
                                                variant="outlined"
                                                sx={{
                                                    p: 2,
                                                    border: isSelected ? "2px solid" : "1px solid",
                                                    borderColor: isSelected ? "success.main" : "divider",
                                                    bgcolor: isSelected ? "success.lighter" : "background.paper",
                                                }}
                                            >
                                                <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                                                    <Box>
                                                        <Box sx={{ display: "flex", alignItems: "center", gap: 1, mb: 0.5 }}>
                                                            <Typography variant="subtitle1" fontWeight="medium">
                                                                {plan.name}
                                                            </Typography>
                                                            {isSelected && (
                                                                <Chip
                                                                    label="Selected"
                                                                    color="success"
                                                                    size="small"
                                                                    icon={<CheckCircleIcon />}
                                                                />
                                                            )}
                                                        </Box>
                                                        {plan.description && (
                                                            <Typography variant="body2" color="text.secondary" gutterBottom>
                                                                {plan.description}
                                                            </Typography>
                                                        )}
                                                        <Typography variant="body2">
                                                            {plan.installment_count} payment{plan.installment_count > 1 ? "s" : ""} of $
                                                            {effectiveInstallmentAmount.toFixed(2)}
                                                            {hasCustomTuition && (
                                                                <Typography component="span" variant="body2" color="text.secondary" sx={{ ml: 1 }}>
                                                                    (was ${parseFloat(plan.installment_amount).toFixed(2)})
                                                                </Typography>
                                                            )}
                                                        </Typography>
                                                        {plan.installment_schedule && plan.installment_schedule.length > 0 && (
                                                            <Typography variant="caption" color="text.secondary">
                                                                Due dates:{" "}
                                                                {plan.installment_schedule
                                                                    .map((s) => {
                                                                        const month = new Date(2026, s.month - 1, 1).toLocaleDateString(
                                                                            "en-US",
                                                                            { month: "short" }
                                                                        );
                                                                        return `${month} ${s.day}`;
                                                                    })
                                                                    .join(", ")}
                                                            </Typography>
                                                        )}
                                                    </Box>
                                                    <Chip
                                                        label={`$${effectiveTotalAmount.toFixed(2)}`}
                                                        color={hasCustomTuition ? "warning" : "primary"}
                                                        size="small"
                                                    />
                                                </Box>
                                            </Paper>
                                        );
                                    })}
                                </Box>
                            ) : (
                                <Typography color="text.secondary">
                                    No payment plans available for this program.
                                </Typography>
                            )}
                        </Box>

                        <Divider />

                        {/* Enrollment Fee Status */}
                        <Box>
                            <Typography variant="h6" gutterBottom>
                                Enrollment Fee Status
                            </Typography>
                            {application.program_enrollment?.enrollment_payment_plan?.enrollment_fee_paid ? (
                                <Alert severity="success" icon={<CheckCircleIcon />}>
                                    <Typography variant="body1" fontWeight="medium">
                                        Enrollment Fee Paid
                                    </Typography>
                                    <Typography variant="body2">
                                        Paid on{" "}
                                        {new Date(
                                            application.program_enrollment.enrollment_payment_plan.enrollment_fee_paid_at
                                        ).toLocaleDateString("en-US", {
                                            month: "long",
                                            day: "numeric",
                                            year: "numeric",
                                        })}
                                    </Typography>
                                </Alert>
                            ) : ["fee_paid", "signing_docs", "enrolled"].includes(application.status) ? (
                                <Alert severity="success" icon={<CheckCircleIcon />}>
                                    <Typography variant="body1" fontWeight="medium">
                                        Enrollment Fee Paid
                                    </Typography>
                                </Alert>
                            ) : (
                                <Alert severity="info">
                                    <Typography variant="body1" fontWeight="medium">
                                        Enrollment Fee Not Yet Paid
                                    </Typography>
                                    {application.status === "fee_requested" && (
                                        <Typography variant="body2">
                                            Fee request has been sent to the parent.
                                        </Typography>
                                    )}
                                </Alert>
                            )}
                        </Box>
                    </Box>
                </TabPanel>
            </Paper>

            {/* Complete Meeting Dialog */}
            <Dialog
                open={showCompleteMeetingDialog}
                onClose={() => setShowCompleteMeetingDialog(false)}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>Complete Meeting</DialogTitle>
                <DialogContent>
                    <Box
                        sx={{
                            display: "flex",
                            flexDirection: "column",
                            gap: 2,
                            pt: 1,
                        }}
                    >
                        <Alert severity="info">
                            Mark this meeting as completed. The application will
                            move to the "Fee Requested" status and the parent
                            will receive the enrollment fee email.
                        </Alert>
                        <TextField
                            label="Outcome Notes (optional)"
                            value={completeMeetingNotes}
                            onChange={(e) =>
                                setCompleteMeetingNotes(e.target.value)
                            }
                            multiline
                            rows={3}
                            fullWidth
                            placeholder="Notes about the meeting outcome..."
                        />
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button
                        onClick={() => {
                            setShowCompleteMeetingDialog(false);
                            setCompleteMeetingNotes("");
                        }}
                    >
                        Cancel
                    </Button>
                    <Button variant="contained" onClick={handleCompleteMeeting}>
                        Complete Meeting
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Meeting Invite Dialog - 3 proposed dates */}
            <Dialog
                open={showMeetingDialog}
                onClose={() => setShowMeetingDialog(false)}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>{hasPendingMeetingInvite ? "Resend Meeting Invite" : "Send Meeting Invite"}</DialogTitle>
                <DialogContent>
                    <Box
                        sx={{
                            display: "flex",
                            flexDirection: "column",
                            gap: 2,
                            pt: 1,
                        }}
                    >
                        <Alert severity="info" sx={{ mb: 1 }}>
                            Propose up to 3 date/time options. The parent will receive an email to select their preferred time.
                        </Alert>
                        <TextField
                            select
                            label="Location"
                            value={meetingForm.location_id}
                            onChange={(e) =>
                                setMeetingForm({
                                    ...meetingForm,
                                    location_id: e.target.value,
                                })
                            }
                            required
                            fullWidth
                        >
                            {locations.map((loc) => (
                                <MenuItem key={loc.id} value={loc.id}>
                                    {loc.name}
                                </MenuItem>
                            ))}
                        </TextField>
                        <Typography variant="subtitle2" sx={{ mt: 1 }}>
                            Proposed Date Options (at least 2 required)
                        </Typography>
                        <TextField
                            label="Option 1"
                            type="datetime-local"
                            value={meetingForm.proposed_date_1}
                            onChange={(e) =>
                                setMeetingForm({
                                    ...meetingForm,
                                    proposed_date_1: e.target.value,
                                })
                            }
                            onFocus={(e) => {
                                if (!meetingForm.proposed_date_1) {
                                    setMeetingForm({
                                        ...meetingForm,
                                        proposed_date_1: getTomorrowAt8AM(),
                                    });
                                }
                            }}
                            required
                            fullWidth
                            slotProps={{ inputLabel: { shrink: true } }}
                        />
                        <TextField
                            label="Option 2"
                            type="datetime-local"
                            value={meetingForm.proposed_date_2}
                            onChange={(e) =>
                                setMeetingForm({
                                    ...meetingForm,
                                    proposed_date_2: e.target.value,
                                })
                            }
                            onFocus={() => {
                                if (!meetingForm.proposed_date_2) {
                                    setMeetingForm({
                                        ...meetingForm,
                                        proposed_date_2: getTomorrowAt8AM(),
                                    });
                                }
                            }}
                            required
                            fullWidth
                            slotProps={{ inputLabel: { shrink: true } }}
                        />
                        <TextField
                            label="Option 3 (optional)"
                            type="datetime-local"
                            value={meetingForm.proposed_date_3}
                            onChange={(e) =>
                                setMeetingForm({
                                    ...meetingForm,
                                    proposed_date_3: e.target.value,
                                })
                            }
                            onFocus={() => {
                                if (!meetingForm.proposed_date_3) {
                                    setMeetingForm({
                                        ...meetingForm,
                                        proposed_date_3: getTomorrowAt8AM(),
                                    });
                                }
                            }}
                            fullWidth
                            slotProps={{ inputLabel: { shrink: true } }}
                        />
                        <TextField
                            label="Notes (optional)"
                            value={meetingForm.notes}
                            onChange={(e) =>
                                setMeetingForm({
                                    ...meetingForm,
                                    notes: e.target.value,
                                })
                            }
                            multiline
                            rows={2}
                            fullWidth
                            placeholder="Any additional details for the parent..."
                        />
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setShowMeetingDialog(false)}>
                        Cancel
                    </Button>
                    <Button
                        variant="contained"
                        onClick={handleSendMeetingInvite}
                        disabled={!meetingForm.location_id || !meetingForm.proposed_date_1 || !meetingForm.proposed_date_2}
                    >
                        Send Invite
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Fee Payment Dialog */}
            <Dialog
                open={showFeeDialog}
                onClose={() => setShowFeeDialog(false)}
                maxWidth="md"
                fullWidth
            >
                <DialogTitle>Select Payment Plan & Record Enrollment Fee</DialogTitle>
                <DialogContent>
                    <Box
                        sx={{
                            display: "flex",
                            flexDirection: "column",
                            gap: 3,
                            pt: 1,
                        }}
                    >
                        <Typography variant="h6">
                            1. Select Tuition Payment Plan
                        </Typography>
                        <PaymentPlanSelector
                            programId={application.program_id}
                            value={feeForm.payment_plan_id}
                            onChange={(planId) =>
                                setFeeForm({
                                    ...feeForm,
                                    payment_plan_id: planId,
                                })
                            }
                        />

                        <Divider />

                        <Typography variant="h6">2. Enrollment Fee Payment Details</Typography>
                        <Alert severity="info" sx={{ mb: 1 }}>
                            Record the <strong>${parseFloat(application.effective_enrollment_fee || application.program?.enrollment_fee || 150).toFixed(2)}</strong> non-refundable enrollment fee payment.
                        </Alert>
                        <TextField
                            select
                            label="Payment Method"
                            value={feeForm.payment_method}
                            onChange={(e) =>
                                setFeeForm({
                                    ...feeForm,
                                    payment_method: e.target.value,
                                })
                            }
                            required
                            fullWidth
                        >
                            <MenuItem value="venmo">Venmo</MenuItem>
                            <MenuItem value="cash">Cash</MenuItem>
                            <MenuItem value="check">Check</MenuItem>
                            <MenuItem value="card">Card</MenuItem>
                            <MenuItem value="other">Other</MenuItem>
                        </TextField>
                        <TextField
                            label="Payment Date"
                            type="date"
                            value={feeForm.payment_date}
                            onChange={(e) =>
                                setFeeForm({
                                    ...feeForm,
                                    payment_date: e.target.value,
                                })
                            }
                            required
                            fullWidth
                            slotProps={{ inputLabel: { shrink: true } }}
                        />
                        <TextField
                            label="Notes"
                            value={feeForm.notes}
                            onChange={(e) =>
                                setFeeForm({
                                    ...feeForm,
                                    notes: e.target.value,
                                })
                            }
                            multiline
                            rows={2}
                            fullWidth
                        />
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setShowFeeDialog(false)}>
                        Cancel
                    </Button>
                    <Button
                        variant="contained"
                        onClick={handleProcessFeePayment}
                        disabled={!feeForm.payment_plan_id}
                    >
                        Record Payment & Create Enrollment
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Email Edit Dialog */}
            <Dialog
                open={showEmailEditDialog}
                onClose={() => setShowEmailEditDialog(false)}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>Edit Parent Email</DialogTitle>
                <DialogContent>
                    <TextField
                        label="Email Address"
                        type="email"
                        value={editedEmail}
                        onChange={(e) => setEditedEmail(e.target.value)}
                        fullWidth
                        sx={{ mt: 1 }}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setShowEmailEditDialog(false)}>
                        Cancel
                    </Button>
                    <Button variant="contained" onClick={handleSaveEmail}>
                        Save
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Decline Confirmation Dialog */}
            <Dialog
                open={showDeclineDialog}
                onClose={() => setShowDeclineDialog(false)}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>Decline Application</DialogTitle>
                <DialogContent>
                    <Alert severity="warning" sx={{ mb: 2 }}>
                        Are you sure you want to decline this application for{" "}
                        <strong>{application?.full_child_name}</strong>? This
                        action cannot be undone.
                    </Alert>
                    <TextField
                        label="Decline Notes (optional)"
                        value={declineNotes}
                        onChange={(e) => setDeclineNotes(e.target.value)}
                        multiline
                        rows={3}
                        fullWidth
                        placeholder="Reason for declining..."
                    />
                </DialogContent>
                <DialogActions>
                    <Button
                        onClick={() => {
                            setShowDeclineDialog(false);
                            setDeclineNotes("");
                        }}
                    >
                        Cancel
                    </Button>
                    <Button
                        variant="contained"
                        color="error"
                        onClick={handleDecline}
                    >
                        Decline Application
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Custom Fees Dialog */}
            <Dialog
                open={showCustomFeesDialog}
                onClose={() => setShowCustomFeesDialog(false)}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>Edit Custom Fees</DialogTitle>
                <DialogContent>
                    <Box
                        sx={{
                            display: "flex",
                            flexDirection: "column",
                            gap: 3,
                            pt: 1,
                        }}
                    >
                        <Alert severity="info">
                            Set custom fees for this family. Leave blank to use program defaults.
                        </Alert>

                        <Box>
                            <TextField
                                label="Custom Enrollment Fee"
                                type="number"
                                value={customFeesForm.customEnrollmentFee}
                                onChange={(e) =>
                                    setCustomFeesForm({
                                        ...customFeesForm,
                                        customEnrollmentFee: e.target.value,
                                    })
                                }
                                fullWidth
                                placeholder={`Program default: $${parseFloat(application?.program?.enrollment_fee || 150).toFixed(2)}`}
                                slotProps={{
                                    input: {
                                        startAdornment: <Typography sx={{ mr: 0.5 }}>$</Typography>,
                                    },
                                }}
                            />
                            {customFeesForm.customEnrollmentFee && (
                                <Button
                                    size="small"
                                    onClick={() => setCustomFeesForm({ ...customFeesForm, customEnrollmentFee: "" })}
                                    sx={{ mt: 0.5 }}
                                >
                                    Reset to Default
                                </Button>
                            )}
                        </Box>

                        <Box>
                            <TextField
                                label="Custom Annual Tuition"
                                type="number"
                                value={customFeesForm.customTuitionAmount}
                                onChange={(e) =>
                                    setCustomFeesForm({
                                        ...customFeesForm,
                                        customTuitionAmount: e.target.value,
                                    })
                                }
                                fullWidth
                                placeholder={`Plan default: $${parseFloat(application?.payment_plans?.[0]?.total_amount || 0).toFixed(2)}`}
                                slotProps={{
                                    input: {
                                        startAdornment: <Typography sx={{ mr: 0.5 }}>$</Typography>,
                                    },
                                }}
                            />
                            {customFeesForm.customTuitionAmount && (
                                <Button
                                    size="small"
                                    onClick={() => setCustomFeesForm({ ...customFeesForm, customTuitionAmount: "" })}
                                    sx={{ mt: 0.5 }}
                                >
                                    Reset to Default
                                </Button>
                            )}
                        </Box>
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setShowCustomFeesDialog(false)}>
                        Cancel
                    </Button>
                    <Button variant="contained" onClick={handleSaveCustomFees}>
                        Save
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Email Notification Toast */}
            <Snackbar
                open={!!emailNotification}
                autoHideDuration={6000}
                onClose={() => setEmailNotification(null)}
                anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
            >
                <Alert
                    onClose={() => setEmailNotification(null)}
                    severity="success"
                    sx={{ width: "100%" }}
                >
                    {emailNotification}
                </Alert>
            </Snackbar>
        </Box>
    );
}
