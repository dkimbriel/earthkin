import { useState, useEffect } from "react";
import {
    Box,
    Typography,
    Card,
    CardContent,
    Chip,
    Alert,
    Stack,
    Table,
    TableHead,
    TableBody,
    TableRow,
    TableCell,
    Button,
    Link,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Checkbox,
    FormControlLabel,
} from "@mui/material";
import AutorenewIcon from "@mui/icons-material/Autorenew";
import { portalApi } from "../../utils/api";
import EarthkinLoader from "../shared/EarthkinLoader";

const money = (v) => `$${Number(v || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}`;

// Parse date-only strings ("2026-08-24") in local time — new Date(str)
// treats them as UTC and shifts the displayed day in western timezones.
const parseDateOnly = (dateStr) => {
    const [y, m, d] = String(dateStr).split("T")[0].split("-");
    return new Date(y, m - 1, d);
};

const formatDue = (dateStr) =>
    parseDateOnly(dateStr).toLocaleDateString(undefined, { weekday: "long", year: "numeric", month: "long", day: "numeric" });

// The next unpaid installment drives the big callout.
const nextPendingInstallment = (row) =>
    row.plan?.installments?.find((inst) => inst.status !== "completed");

// Turn automatic payments on, change the saved method, or turn them off for
// one enrollment. Saving a method happens on Stripe's hosted page after the
// parent agrees to the terms here; autopay switches on when Stripe confirms.
function AutopayPanel({ plan, onChanged }) {
    const autopay = plan.autopay || {};
    const [open, setOpen] = useState(false);
    const [agreed, setAgreed] = useState(false);
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState(null);

    const startSetup = async () => {
        setBusy(true);
        setError(null);
        try {
            const { url } = await portalApi.setupAutopay(plan.id, true);
            window.location.assign(url);
        } catch (err) {
            setError(err.message);
            setBusy(false);
        }
    };

    const turnOff = async () => {
        if (!window.confirm("Turn off automatic payments? You'll pay each installment yourself from this page or the reminder email.")) return;
        setBusy(true);
        setError(null);
        try {
            await portalApi.disableAutopay(plan.id);
            onChanged();
        } catch (err) {
            setError(err.message);
        } finally {
            setBusy(false);
        }
    };

    return (
        <Box sx={{ my: 2, p: 2, borderRadius: 2, border: 1, borderColor: autopay.enabled ? "success.main" : "divider" }}>
            {error && <Alert severity="error" sx={{ mb: 1 }}>{error}</Alert>}
            {autopay.enabled ? (
                <Stack direction={{ xs: "column", sm: "row" }} spacing={1} alignItems={{ sm: "center" }} justifyContent="space-between">
                    <Box>
                        <Typography sx={{ fontWeight: 600, display: "flex", alignItems: "center", gap: 0.5 }}>
                            <AutorenewIcon fontSize="small" color="success" /> Autopay is on
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            Each installment is charged to your {autopay.method_label} on its due date.
                        </Typography>
                    </Box>
                    <Stack direction="row" spacing={1}>
                        <Button size="small" disabled={busy} onClick={() => setOpen(true)}>Change payment method</Button>
                        <Button size="small" color="error" disabled={busy} onClick={turnOff}>Turn off</Button>
                    </Stack>
                </Stack>
            ) : (
                <Stack direction={{ xs: "column", sm: "row" }} spacing={1} alignItems={{ sm: "center" }} justifyContent="space-between">
                    <Box>
                        <Typography sx={{ fontWeight: 600 }}>Pay automatically</Typography>
                        <Typography variant="body2" color="text.secondary">
                            Save a card or bank account and each installment is paid on its due date. You can turn it off anytime.
                        </Typography>
                    </Box>
                    <Button variant="contained" disabled={busy} onClick={() => setOpen(true)} sx={{ flexShrink: 0 }}>
                        Set up autopay
                    </Button>
                </Stack>
            )}

            <Dialog open={open} onClose={() => !busy && setOpen(false)} maxWidth="sm" fullWidth>
                <DialogTitle>{autopay.enabled ? "Change your autopay payment method" : "Set up automatic payments"}</DialogTitle>
                <DialogContent>
                    <Typography variant="body2" sx={{ mb: 2 }}>{plan.autopay_terms}</Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        Next you'll enter a card or bank account on Stripe's secure page. Nothing is charged until an installment is due.
                    </Typography>
                    <FormControlLabel
                        control={<Checkbox checked={agreed} onChange={(e) => setAgreed(e.target.checked)} />}
                        label="I agree to these automatic payment terms"
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setOpen(false)} disabled={busy}>Cancel</Button>
                    <Button variant="contained" onClick={startSetup} disabled={!agreed || busy}>
                        {busy ? "Starting…" : "Continue to Stripe"}
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
}

export default function ParentPaymentsPage() {
    const [rows, setRows] = useState(null);
    const [error, setError] = useState(null);
    const [loading, setLoading] = useState(true);
    const [payError, setPayError] = useState(null);
    const [paying, setPaying] = useState(false);

    // Stripe sends the parent back with ?autopay=1 after saving a method; the
    // webhook that turns autopay on may land a moment later, so look again.
    const [autopayReturned] = useState(() => new URLSearchParams(window.location.search).get("autopay") === "1");

    const loadPayments = () =>
        portalApi
            .payments()
            .then(setRows)
            .catch((err) => setError(err.message))
            .finally(() => setLoading(false));

    useEffect(() => {
        loadPayments();
        if (!autopayReturned) return undefined;
        const timer = setTimeout(loadPayments, 4000);
        return () => clearTimeout(timer);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // Kick off a Stripe Checkout for one installment, then hand off to Stripe's
    // hosted page. On success/cancel Stripe returns the parent to this page.
    const payInstallment = async (planId, installmentIndex) => {
        if (!planId) return;
        setPayError(null);
        setPaying(true);
        try {
            const { url } = await portalApi.createPaymentCheckout(planId, installmentIndex);
            window.location.assign(url);
        } catch (err) {
            setPayError(err.message);
            setPaying(false);
        }
    };

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

    return (
        <Box>
            <Typography variant="h4" gutterBottom>
                Payments
            </Typography>

            {rows.length === 0 && <Alert severity="info">No enrollments with payments yet.</Alert>}

            {autopayReturned && (
                <Alert severity="success" sx={{ mb: 2 }}>
                    Thanks! Your payment method is saved. Autopay shows as on below once Stripe confirms, usually within a minute.
                </Alert>
            )}

            {payError && (
                <Alert severity="error" sx={{ mb: 2 }} onClose={() => setPayError(null)}>
                    {payError}
                </Alert>
            )}

            <Stack spacing={3}>
                {rows.map((row) => (
                    <Card key={row.enrollment_id}>
                        <CardContent>
                            <Typography variant="h6">
                                {row.child_name} — {row.program_name}
                            </Typography>

                            {(() => {
                                const next = nextPendingInstallment(row);
                                if (next) {
                                    const nextIdx = row.plan.installments.findIndex((inst) => inst.status !== "completed");
                                    const overdue = parseDateOnly(next.due_date) < new Date();
                                    return (
                                        <Box
                                            sx={{
                                                my: 2,
                                                p: 2,
                                                borderRadius: 2,
                                                textAlign: "center",
                                                backgroundColor: overdue ? "error.light" : "primary.light",
                                                color: overdue ? "error.contrastText" : "primary.contrastText",
                                            }}
                                        >
                                            <Typography variant="overline" sx={{ letterSpacing: 1 }}>
                                                {overdue ? "Payment Overdue" : "Next Payment Due"}
                                            </Typography>
                                            <Typography variant="h3" sx={{ fontWeight: 700, lineHeight: 1.1 }}>
                                                {money(next.amount)}
                                            </Typography>
                                            <Typography variant="h6">{formatDue(next.due_date)}</Typography>
                                            {row.plan?.id && (
                                                <Button
                                                    variant="contained"
                                                    color="inherit"
                                                    sx={{ mt: 1.5, color: "text.primary", backgroundColor: "background.paper" }}
                                                    disabled={paying}
                                                    onClick={() => payInstallment(row.plan.id, nextIdx)}
                                                >
                                                    {paying ? "Starting…" : "Pay Now"}
                                                </Button>
                                            )}
                                        </Box>
                                    );
                                }
                                if (Number(row.balance_due) <= 0) {
                                    return (
                                        <Box sx={{ my: 2, p: 2, borderRadius: 2, textAlign: "center", backgroundColor: "success.light" }}>
                                            <Typography variant="h6" sx={{ color: "success.contrastText" }}>
                                                🎉 All paid up — no payments due
                                            </Typography>
                                        </Box>
                                    );
                                }
                                return null;
                            })()}

                            {row.plan?.id && nextPendingInstallment(row) && (
                                <AutopayPanel plan={row.plan} onChanged={loadPayments} />
                            )}

                            <Stack direction="row" spacing={3} sx={{ my: 1, flexWrap: "wrap" }}>
                                <Typography variant="body2">Total: {money(row.total_owed)}</Typography>
                                <Typography variant="body2" color="success.main">
                                    Paid: {money(row.total_paid)}
                                </Typography>
                                <Typography
                                    variant="body2"
                                    color={Number(row.balance_due) > 0 ? "error.main" : "text.secondary"}
                                >
                                    Balance: {money(row.balance_due)}
                                </Typography>
                                {row.plan?.name && <Chip size="small" label={row.plan.name} />}
                            </Stack>

                            {row.plan?.installments?.length > 0 && (
                                <>
                                    <Typography variant="subtitle2" sx={{ mt: 2 }}>
                                        Payment Schedule ({row.plan.name || "your plan"})
                                    </Typography>
                                    <Table size="small">
                                        <TableHead>
                                            <TableRow>
                                                <TableCell>Due Date</TableCell>
                                                <TableCell>Amount</TableCell>
                                                <TableCell>Status</TableCell>
                                            </TableRow>
                                        </TableHead>
                                        <TableBody>
                                            {(() => {
                                                const nextIdx = row.plan.installments.findIndex((inst) => inst.status !== "completed");
                                                return row.plan.installments.map((inst, i) => (
                                                    <TableRow
                                                        key={i}
                                                        sx={i === nextIdx ? { backgroundColor: "action.selected", "& td": { fontWeight: 700 } } : undefined}
                                                    >
                                                        <TableCell>{parseDateOnly(inst.due_date).toLocaleDateString()}</TableCell>
                                                        <TableCell>{money(inst.amount)}</TableCell>
                                                        <TableCell>
                                                            <Chip
                                                                size="small"
                                                                label={inst.status === "completed" ? "Paid" : i === nextIdx ? "Due next" : "Upcoming"}
                                                                color={inst.status === "completed" ? "success" : i === nextIdx ? "warning" : "default"}
                                                            />
                                                        </TableCell>
                                                    </TableRow>
                                                ));
                                            })()}
                                        </TableBody>
                                    </Table>
                                </>
                            )}

                            {row.payments.length > 0 && (
                                <>
                                    <Typography variant="subtitle2" sx={{ mt: 2 }}>
                                        Completed Payments
                                    </Typography>
                                    <Table size="small">
                                        <TableHead>
                                            <TableRow>
                                                <TableCell>Date</TableCell>
                                                <TableCell>Amount</TableCell>
                                                <TableCell>Type</TableCell>
                                                <TableCell>Method</TableCell>
                                                <TableCell>Status</TableCell>
                                                <TableCell>Receipt</TableCell>
                                            </TableRow>
                                        </TableHead>
                                        <TableBody>
                                            {row.payments.map((p) => (
                                                <TableRow key={p.id}>
                                                    <TableCell>{parseDateOnly(p.payment_date).toLocaleDateString()}</TableCell>
                                                    <TableCell>{money(p.amount)}</TableCell>
                                                    <TableCell>{p.payment_type?.replace("_", " ")}</TableCell>
                                                    <TableCell>{p.payment_method || "—"}</TableCell>
                                                    <TableCell>
                                                        <Chip
                                                            size="small"
                                                            label={p.status}
                                                            color={p.status === "completed" ? "success" : "default"}
                                                        />
                                                    </TableCell>
                                                    <TableCell>
                                                        {p.receipt_url ? (
                                                            <Link href={p.receipt_url} target="_blank" rel="noopener">
                                                                View
                                                            </Link>
                                                        ) : (
                                                            "—"
                                                        )}
                                                    </TableCell>
                                                </TableRow>
                                            ))}
                                        </TableBody>
                                    </Table>
                                </>
                            )}
                        </CardContent>
                    </Card>
                ))}
            </Stack>
        </Box>
    );
}
