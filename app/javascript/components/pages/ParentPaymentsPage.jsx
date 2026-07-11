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
                                        Payment Schedule
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
                                            {row.plan.installments.map((inst, i) => (
                                                <TableRow key={i}>
                                                    <TableCell>{new Date(inst.due_date).toLocaleDateString()}</TableCell>
                                                    <TableCell>{money(inst.amount)}</TableCell>
                                                    <TableCell>
                                                        <Chip
                                                            size="small"
                                                            label={inst.status === "completed" ? "Paid" : "Due"}
                                                            color={inst.status === "completed" ? "success" : "warning"}
                                                        />
                                                    </TableCell>
                                                </TableRow>
                                            ))}
                                        </TableBody>
                                    </Table>
                                </>
                            )}

                            {row.payments.length > 0 && (
                                <>
                                    <Typography variant="subtitle2" sx={{ mt: 2 }}>
                                        Payment History
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
                                                    <TableCell>{new Date(p.payment_date).toLocaleDateString()}</TableCell>
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
