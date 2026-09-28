import { useState, useEffect } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  TextField,
  Box,
  Alert,
  Chip,
  IconButton,
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableCell,
  Typography,
  Tooltip,
} from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import AddIcon from '@mui/icons-material/Add';
import { enrollmentPaymentPlansApi } from '../../utils/api';

const toCents = (value) => {
  const n = parseFloat(value);
  return Number.isFinite(n) ? Math.round(n * 100) : NaN;
};

const formatMoney = (cents) => (cents / 100).toFixed(2);

// One month after an ISO date, clamped to the end of the month (Jan 31 -> Feb 28).
const nextMonth = (iso) => {
  const [y, m, d] = iso.split('-').map(Number);
  const lastDay = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
  const date = new Date(Date.UTC(y, m, Math.min(d, lastDay)));
  return date.toISOString().split('T')[0];
};

// Paid installments can't change at all; invoiced ones can be edited (their
// pending invoice follows) but not removed. Payments point at installments by
// position (installment_number = index + 1).
const buildRows = (plan, payments) => {
  const invoiced = new Set(
    (payments || [])
      .filter((p) => p.payment_type === 'tuition' && p.status !== 'refunded' && p.installment_number)
      .map((p) => p.installment_number - 1)
  );

  return (plan.installments || []).map((inst, index) => {
    const paid = inst.status === 'completed' || !!inst.paid_at;
    return {
      key: `orig-${index}`,
      due_date: String(inst.due_date),
      amount: parseFloat(inst.amount).toFixed(2),
      original_index: index,
      lock: paid ? 'paid' : invoiced.has(index) ? 'invoiced' : null,
    };
  });
};

export default function EditScheduleDialog({ open, onClose, onSaved, plan, payments }) {
  const [total, setTotal] = useState('');
  const [rows, setRows] = useState([]);
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open || !plan) return;
    setTotal(parseFloat(plan.total_amount).toFixed(2));
    setRows(buildRows(plan, payments));
    setError(null);
  }, [open, plan, payments]);

  const totalCents = toCents(total);
  const sumCents = rows.reduce((acc, r) => acc + (toCents(r.amount) || 0), 0);
  const difference = totalCents - sumCents;
  const invalidRow = rows.some((r) => !r.due_date || !(toCents(r.amount) > 0));
  const canSave = rows.length > 0 && totalCents > 0 && difference === 0 && !invalidRow && !saving;

  const updateRow = (key, field, value) => {
    setRows((prev) => prev.map((r) => (r.key === key ? { ...r, [field]: value } : r)));
  };

  // Removing a row shifts everything after it, and paid/invoiced rows must
  // keep their position, so only rows after the last locked one can go.
  const lastLockedIndex = rows.reduce((acc, r, i) => (r.lock ? i : acc), -1);
  const removeBlockedReason = (row, index) => {
    if (row.lock === 'paid') return "Can't remove a paid installment";
    if (row.lock === 'invoiced') return "Can't remove an invoiced installment";
    if (index < lastLockedIndex) return 'Removing this would move a paid or invoiced installment';
    return null;
  };

  const removeRow = (key) => {
    setRows((prev) => prev.filter((r) => r.key !== key));
  };

  const addRow = () => {
    setRows((prev) => {
      const last = prev[prev.length - 1];
      const due = last?.due_date ? nextMonth(last.due_date) : new Date().toISOString().split('T')[0];
      return [...prev, { key: `new-${Date.now()}`, due_date: due, amount: '0.00', original_index: null, lock: null }];
    });
  };

  // Spread what's left of the total (after paid installments) across the
  // other rows, leftover cents on the first of them.
  const splitEvenly = () => {
    const editable = rows.filter((r) => r.lock !== 'paid');
    if (editable.length === 0 || !(totalCents > 0)) return;

    const paidCents = rows.filter((r) => r.lock === 'paid').reduce((acc, r) => acc + toCents(r.amount), 0);
    const remaining = totalCents - paidCents;
    if (remaining <= 0) return;

    const base = Math.floor(remaining / editable.length);
    const extra = remaining - base * editable.length;
    const firstOpenKey = editable[0].key;
    setRows((prev) => prev.map((r) => {
      if (r.lock === 'paid') return r;
      const cents = base + (r.key === firstOpenKey ? extra : 0);
      return { ...r, amount: formatMoney(cents) };
    }));
  };

  const handleSave = async () => {
    setError(null);
    setSaving(true);
    try {
      await enrollmentPaymentPlansApi.update(plan.id, {
        total_amount: total,
        installments: rows.map((r) => ({
          due_date: r.due_date,
          amount: r.amount,
          original_index: r.original_index,
        })),
      });
      onSaved();
      onClose();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle>Edit Payment Schedule</DialogTitle>
      <DialogContent>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}
        <Box sx={{ display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap', mt: 1, mb: 2 }}>
          <TextField
            label="Total Tuition ($)"
            type="number"
            size="small"
            value={total}
            onChange={(e) => setTotal(e.target.value)}
            inputProps={{ step: '0.01', min: '0' }}
          />
          <Button variant="outlined" size="small" onClick={splitEvenly}>
            Split evenly
          </Button>
          <Typography variant="body2" color={difference === 0 ? 'success.main' : 'error.main'}>
            Installments: ${formatMoney(sumCents)}
            {Number.isFinite(difference) && difference !== 0 && (
              <> ({difference > 0 ? `$${formatMoney(difference)} short` : `$${formatMoney(-difference)} over`})</>
            )}
          </Typography>
        </Box>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>#</TableCell>
              <TableCell>Due date</TableCell>
              <TableCell>Amount ($)</TableCell>
              <TableCell>Status</TableCell>
              <TableCell />
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((row, index) => (
              <TableRow key={row.key}>
                <TableCell>{index + 1}</TableCell>
                <TableCell>
                  <TextField
                    type="date"
                    size="small"
                    value={row.due_date}
                    disabled={row.lock === 'paid'}
                    onChange={(e) => updateRow(row.key, 'due_date', e.target.value)}
                  />
                </TableCell>
                <TableCell>
                  <TextField
                    type="number"
                    size="small"
                    value={row.amount}
                    disabled={row.lock === 'paid'}
                    onChange={(e) => updateRow(row.key, 'amount', e.target.value)}
                    inputProps={{ step: '0.01', min: '0' }}
                  />
                </TableCell>
                <TableCell>
                  {row.lock === 'paid' && <Chip label="Paid" color="success" size="small" />}
                  {row.lock === 'invoiced' && <Chip label="Invoiced" color="warning" size="small" />}
                  {!row.lock && <Chip label={row.original_index === null ? 'New' : 'Upcoming'} size="small" />}
                </TableCell>
                <TableCell align="right">
                  <Tooltip title={removeBlockedReason(row, index) || 'Remove'}>
                    <span>
                      <IconButton size="small" disabled={!!removeBlockedReason(row, index)} onClick={() => removeRow(row.key)}>
                        <DeleteIcon fontSize="small" />
                      </IconButton>
                    </span>
                  </Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
        <Button startIcon={<AddIcon />} size="small" sx={{ mt: 1 }} onClick={addRow}>
          Add installment
        </Button>
        <Typography variant="caption" color="text.secondary" component="p" sx={{ mt: 1 }}>
          Due dates must be in order. Editing an invoiced installment updates its pending invoice.
        </Typography>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={handleSave} disabled={!canSave}>
          {saving ? 'Saving…' : 'Save'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
