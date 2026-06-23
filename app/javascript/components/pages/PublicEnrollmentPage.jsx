import { useState, useEffect } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import {
  Container,
  Box,
  Typography,
  Paper,
  Alert,
  CircularProgress,
  Card,
  CardContent,
} from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import EnrollmentFormContent from '../enrollment/EnrollmentFormContent';
import { programsApi } from '../../utils/api';

export default function PublicEnrollmentPage() {
  const [searchParams] = useSearchParams();
  const programId = searchParams.get('program_id');
  const applicationId = searchParams.get('application_id');
  const [program, setProgram] = useState(null);
  const [loading, setLoading] = useState(true);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    const loadProgram = async () => {
      if (!programId) {
        setError('No program specified');
        setLoading(false);
        return;
      }

      try {
        const data = await programsApi.get(programId);
        setProgram(data);
      } catch (err) {
        setError('Program not found');
      } finally {
        setLoading(false);
      }
    };

    loadProgram();
  }, [programId]);

  const handleSuccess = () => {
    setSubmitted(true);
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="100vh">
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Container maxWidth="md" sx={{ mt: 8 }}>
        <Alert severity="error">{error}</Alert>
      </Container>
    );
  }

  if (submitted) {
    return (
      <Container maxWidth="md" sx={{ mt: 8 }}>
        <Card>
          <CardContent sx={{ textAlign: 'center', p: 6 }}>
            <CheckCircleIcon color="success" sx={{ fontSize: 80, mb: 2 }} />
            <Typography variant="h4" gutterBottom>
              Application Submitted!
            </Typography>
            <Typography variant="body1" color="text.secondary" paragraph>
              Thank you for your interest in {program?.name}. We've received your application
              and will be in touch soon to schedule a meet-and-greet.
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Please check your email for confirmation and next steps.
            </Typography>
          </CardContent>
        </Card>
      </Container>
    );
  }

  return (
    <Container maxWidth="md" sx={{ py: 2 }}>
      <Paper sx={{ p: 4 }}>
        <Box sx={{ mb: 3 }}>
          <img
            src="/logo.png"
            alt="Earthkin Nature School"
            style={{ height: 60, marginBottom: 16 }}
          />
          <Typography variant="h4" gutterBottom>
            Program Enrollment Application
          </Typography>
          {program && (
            <Typography variant="h6" color="text.secondary" gutterBottom>
              {program.name}
            </Typography>
          )}
          {program?.description && (
            <Typography variant="body2" color="text.secondary" paragraph>
              {program.description}
            </Typography>
          )}
        </Box>

        <EnrollmentFormContent
          programId={programId}
          applicationId={applicationId}
          onSuccess={handleSuccess}
        />
      </Paper>
    </Container>
  );
}
