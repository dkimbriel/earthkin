import { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Chip,
  Alert,
  CircularProgress,
  Stack,
} from '@mui/material';
import { portalApi } from '../../utils/api';

const STATUS_COLORS = { confirmed: 'success', pending: 'warning', cancelled: 'default' };

const WORKFLOW_LABELS = {
  fee_paid: 'Enrollment fee paid',
  signing_docs: 'Forms out for signature',
  enrolled: 'Enrolled',
};

export default function ParentDashboardPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [overview, setOverview] = useState(null);

  useEffect(() => {
    portalApi
      .overview()
      .then(setOverview)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
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
        Welcome, {overview.family.name}
      </Typography>

      <Typography variant="h6" sx={{ mt: 3, mb: 1 }}>
        Your Children
      </Typography>

      {overview.children.length === 0 && (
        <Alert severity="info">No children on file yet. Reach out to the school if this looks wrong.</Alert>
      )}

      <Stack spacing={2}>
        {overview.children.map((child) => (
          <Card key={child.id}>
            <CardContent>
              <Typography variant="h6">{child.name}</Typography>
              {child.enrollments.length === 0 ? (
                <Typography color="text.secondary">No enrollments yet.</Typography>
              ) : (
                child.enrollments.map((enr) => (
                  <Box
                    key={enr.id}
                    sx={{ display: 'flex', alignItems: 'center', gap: 1, mt: 1, flexWrap: 'wrap' }}
                  >
                    <Typography>{enr.program_name}</Typography>
                    <Chip
                      size="small"
                      label={enr.status}
                      color={STATUS_COLORS[enr.status] || 'default'}
                    />
                    {enr.workflow_status && WORKFLOW_LABELS[enr.workflow_status] && (
                      <Chip size="small" variant="outlined" label={WORKFLOW_LABELS[enr.workflow_status]} />
                    )}
                    {enr.program_start_date && (
                      <Typography variant="body2" color="text.secondary">
                        starts {new Date(enr.program_start_date).toLocaleDateString()}
                      </Typography>
                    )}
                  </Box>
                ))
              )}
            </CardContent>
          </Card>
        ))}
      </Stack>

      <Typography variant="h6" sx={{ mt: 4, mb: 1 }}>
        Family Contacts
      </Typography>
      <Card>
        <CardContent>
          {overview.parents.map((p) => (
            <Typography key={p.id}>
              {p.name} — {p.email}
            </Typography>
          ))}
        </CardContent>
      </Card>
    </Box>
  );
}
