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
    Table,
    TableHead,
    TableBody,
    TableRow,
    TableCell,
} from "@mui/material";
import { portalApi } from "../../utils/api";

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

export default function ParentPaymentsPage() {
    const [rows, setRows] = useState(null);
    const [error, setError] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        portalApi
            .payments()
            .then(setRows)
            .catch((err) => setError(err.message))
            .finally(() => setLoading(false));
    }, []);

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

    return (
        <Box>
            <Typography variant="h4" gutterBottom>
                Payments
            </Typography>

            {rows.length === 0 && <Alert severity="info">No enrollments with payments yet.</Alert>}

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
