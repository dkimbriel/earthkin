import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  Chip,
  Button,
  Paper,
  List,
  ListItem,
  ListItemText,
  Divider,
  Alert,
  CircularProgress,
  Stepper,
  Step,
  StepLabel,
} from '@mui/material';
import { enrollmentApplicationsApi, api } from '../../utils/api';

const WORKFLOW_STEPS = [
  { key: 'submitted', label: 'Application Submitted' },
  { key: 'reviewed', label: 'Application Reviewed' },
  { key: 'meeting_scheduled', label: 'Meet & Greet Scheduled' },
  { key: 'meeting_completed', label: 'Meet & Greet Completed' },
  { key: 'fee_requested', label: 'Enrollment Fee Requested' },
  { key: 'fee_paid', label: 'Enrollment Fee Paid' },
  { key: 'enrolled', label: 'Enrolled!' },
];

export default function ParentDashboardPage() {
  const [loading, setLoading] = useState(true);
  const [applications, setApplications] = useState([]);
  const [enrollments, setEnrollments] = useState([]);
  const [currentUser, setCurrentUser] = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      // Get current user to find their parent record
      const userData = await api.get('/api/current_user');
      setCurrentUser(userData);

      // For now, get all applications for the logged-in parent's email
      // In production, you'd have an endpoint filtered by current user
      const apps = await enrollmentApplicationsApi.list();
      const userApps = apps.filter(app => app.parent_email === userData.email);
      setApplications(userApps);

      // Load enrollments if any
      // const enr = await programEnrollmentsApi.list({ parent_email: user.email });
      // setEnrollments(enr);
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  const getActiveStepIndex = (status) => {
    const index = WORKFLOW_STEPS.findIndex(step => step.key === status);
    return index >= 0 ? index : 0;
  };

  const getStatusColor = (status) => {
    const colors = {
      submitted: 'info',
      reviewed: 'info',
      meeting_scheduled: 'primary',
      meeting_completed: 'primary',
      fee_requested: 'warning',
      fee_paid: 'success',
      enrolled: 'success',
      declined: 'error',
    };
    return colors[status] || 'default';
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="80vh">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Welcome{currentUser?.email ? `, ${currentUser.email}` : ''}!
      </Typography>

      {applications.length === 0 ? (
        <Alert severity="info" sx={{ mt: 2 }}>
          You don't have any enrollment applications yet.
          <Button color="primary" onClick={() => navigate('/enroll')}>
            Start an Application
          </Button>
        </Alert>
      ) : (
        <Box sx={{ mt: 3 }}>
          <Typography variant="h5" gutterBottom>
            Your Enrollment Applications
          </Typography>

          {applications.map((application) => (
            <Paper key={application.id} sx={{ p: 3, mb: 3 }}>
              <Grid container spacing={2}>
                <Grid item xs={12} md={8}>
                  <Typography variant="h6" gutterBottom>
                    {application.child_first_name} {application.child_last_name}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" gutterBottom>
                    Program: {application.program?.name}
                  </Typography>
                  <Chip
                    label={application.status.replace(/_/g, ' ').toUpperCase()}
                    color={getStatusColor(application.status)}
                    size="small"
                    sx={{ mt: 1 }}
                  />
                </Grid>

                <Grid item xs={12} md={4}>
                  {application.meet_and_greet && (
                    <Card variant="outlined">
                      <CardContent>
                        <Typography variant="subtitle2" color="text.secondary">
                          Meet & Greet
                        </Typography>
                        <Typography variant="body2">
                          {new Date(application.meet_and_greet.scheduled_at).toLocaleDateString()}
                        </Typography>
                        <Typography variant="body2">
                          {new Date(application.meet_and_greet.scheduled_at).toLocaleTimeString()}
                        </Typography>
                      </CardContent>
                    </Card>
                  )}
                </Grid>
              </Grid>

              <Box sx={{ mt: 3 }}>
                <Typography variant="subtitle2" gutterBottom>
                  Application Progress
                </Typography>
                <Stepper activeStep={getActiveStepIndex(application.status)} alternativeLabel>
                  {WORKFLOW_STEPS.map((step) => (
                    <Step key={step.key}>
                      <StepLabel>{step.label}</StepLabel>
                    </Step>
                  ))}
                </Stepper>
              </Box>

              {application.status === 'fee_requested' && (
                <Alert severity="warning" sx={{ mt: 2 }}>
                  <Typography variant="subtitle2">Action Required: Pay Enrollment Fee</Typography>
                  <Typography variant="body2">
                    Please submit your ${parseFloat(application.effective_enrollment_fee || application.program?.enrollment_fee || 150).toFixed(0)} enrollment fee via Venmo to continue.
                    Once paid, notify us and we'll update your status.
                  </Typography>
                  <Button variant="contained" color="primary" sx={{ mt: 1 }}>
                    Mark Fee as Paid
                  </Button>
                </Alert>
              )}

              {application.status === 'enrolled' && application.enrollment_payment_plan && (
                <Card variant="outlined" sx={{ mt: 2, bgcolor: 'success.50' }}>
                  <CardContent>
                    <Typography variant="subtitle2" color="success.main" gutterBottom>
                      🎉 Congratulations! You're Enrolled!
                    </Typography>
                    <Typography variant="body2">
                      Payment Plan: {application.enrollment_payment_plan.payment_plan?.name}
                    </Typography>
                    <Typography variant="body2">
                      Balance Due: ${application.enrollment_payment_plan.balance_due || 0}
                    </Typography>
                  </CardContent>
                </Card>
              )}
            </Paper>
          ))}
        </Box>
      )}
    </Box>
  );
}
