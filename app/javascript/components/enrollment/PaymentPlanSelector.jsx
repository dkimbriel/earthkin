import { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Radio,
  RadioGroup,
  FormControlLabel,
  Chip,
  Alert,
} from '@mui/material';
import { paymentPlansApi } from '../../utils/api';
import EarthkinLoader from '../shared/EarthkinLoader';

export default function PaymentPlanSelector({ programId, value, onChange }) {
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadPlans();
  }, [programId]);

  const loadPlans = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await paymentPlansApi.list(programId, true);
      setPlans(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <EarthkinLoader />;
  if (error) return <Alert severity="error">{error}</Alert>;

  return (
    <RadioGroup value={value} onChange={(e) => onChange(e.target.value)}>
      <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        {plans.map((plan) => (
          <Card
            key={plan.id}
            variant="outlined"
            sx={{
              cursor: 'pointer',
              border: value === plan.id ? '2px solid' : '1px solid',
              borderColor: value === plan.id ? 'primary.main' : 'divider',
              bgcolor: value === plan.id ? 'action.selected' : 'background.paper',
            }}
            onClick={() => onChange(plan.id)}
          >
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 2 }}>
                <FormControlLabel
                  value={plan.id}
                  control={<Radio />}
                  label=""
                  sx={{ m: 0 }}
                />
                <Box sx={{ flex: 1 }}>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                    <Typography variant="h6">{plan.name}</Typography>
                    <Chip
                      label={`$${parseFloat(plan.total_amount).toFixed(2)}`}
                      color="primary"
                      size="small"
                    />
                  </Box>
                  {plan.description && (
                    <Typography variant="body2" color="text.secondary" gutterBottom>
                      {plan.description}
                    </Typography>
                  )}
                  <Typography variant="body2">
                    {plan.installment_count} payment{plan.installment_count > 1 ? 's' : ''} of
                    ${parseFloat(plan.installment_amount).toFixed(2)}
                  </Typography>
                  {plan.installment_schedule && plan.installment_schedule.length > 0 && (
                    <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                      Due dates: {plan.installment_schedule.map(s => {
                        const month = new Date(2026, s.month - 1, 1).toLocaleDateString('en-US', { month: 'short' });
                        return `${month} ${s.day}`;
                      }).join(', ')}
                    </Typography>
                  )}
                </Box>
              </Box>
            </CardContent>
          </Card>
        ))}
      </Box>
    </RadioGroup>
  );
}
