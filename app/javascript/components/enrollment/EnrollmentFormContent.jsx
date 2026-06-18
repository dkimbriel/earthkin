import { useState } from 'react';
import {
  Button,
  Stepper,
  Step,
  StepLabel,
  TextField,
  Box,
  Alert,
  Typography,
  MenuItem,
  FormControlLabel,
  Checkbox,
  FormGroup,
  FormHelperText,
} from '@mui/material';
import { enrollmentApplicationsApi } from '../../utils/api';
import { formatPhoneNumber } from '../../utils/phoneFormatter';

const steps = ['Child Info', 'Parent Info', 'Program Interest', 'Agreements'];

const RACE_ETHNICITY_OPTIONS = [
  'Native American or Alaska Native',
  'Euro-American or White',
  'African American or Black',
  'Hispanic or Latino',
  'Middle Eastern or North African',
  'Native Hawaiian or Pacific Islander',
  'Asian',
  'Other',
];

const IS_LOCAL_OPTIONS = [
  { value: 'yes', label: 'Yes' },
  { value: 'no', label: 'No' },
  { value: 'not_sure', label: "I'm not sure" },
];

const REFERRAL_SOURCE_OPTIONS = [
  'Instagram',
  'Facebook',
  'Friend or colleague',
  'Posted flyer around town',
  'Other',
];

const AGREEMENT_ITEMS = [
  {
    key: 'program_details',
    label: 'I understand that this application is for Earthkin\'s 2026–27 Nature Preschool drop-off program, held Mondays & Wednesdays from 9:00 AM–12:00 PM at Forest Hill Park from August 24, 2026–June 2, 2027. Annual tuition is $2,800.',
  },
  {
    key: 'enrollment_fee',
    label: 'I understand that a non-refundable enrollment fee of $150 is due upon enrollment to reserve my child\'s spot in the program.',
  },
  {
    key: 'sibling_discount',
    label: 'I understand that a 10% sibling discount is applied to any younger sibling\'s tuition while both children are concurrently enrolled in the program. I also understand that enrollment fees apply separately to each child.',
  },
  {
    key: 'payment_terms',
    label: 'I understand that the annual tuition of $2,800 can be paid in full by August 1 OR in payment installments. I am expected to pay for the full program season, even if my child does not attend all scheduled classes.',
  },
  {
    key: 'outdoor_programming',
    label: 'I understand that this is an entirely outdoor program, conducted in all elements except severe weather.',
  },
  {
    key: 'weather_policy',
    label: 'I understand that weather or other environmental conditions may occasionally require class to be canceled for safety. In the event of a cancellation, I acknowledge that Earthkin is not obligated to issue a refund.',
  },
  {
    key: 'emergent_curriculum',
    label: 'I understand that Earthkin uses a child-led, teacher-supported, seasonally aligned curriculum that encourages developmentally appropriate risky and messy play, fostering leadership, collaboration, critical thinking, and choice-making.',
  },
  {
    key: 'follow_instructions',
    label: 'I understand that my child must be able to follow basic instructions carefully for safety in the outdoor environment.',
  },
  {
    key: 'toilet_proficiency',
    label: 'I understand that my child must be toilet-proficient. They need to know when they have to go and be able to communicate that.',
  },
  {
    key: 'meet_and_greet',
    label: 'I understand that I will need to attend a meet-and-greet with my child before enrollment is finalized.',
  },
  {
    key: 'application_status',
    label: 'I understand that this application is NOT a contract. Following review, Earthkin will reach out to schedule a meet-and-greet. If all spaces are full, my child will be placed on a waiting list.',
  },
];

export default function EnrollmentFormContent({ programId, applicationId, onSuccess, onCancel }) {
  const [activeStep, setActiveStep] = useState(0);
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const [formData, setFormData] = useState({
    program_id: programId,
    application_id: applicationId,
    // Child info
    child_first_name: '',
    child_last_name: '',
    child_date_of_birth: '',
    child_race_ethnicity: '',
    child_description: '',
    // Parent 1 info
    parent_first_name: '',
    parent_last_name: '',
    parent_email: '',
    parent_email_confirm: '', // Not saved, just for validation
    parent_phone: '',
    // Parent 2 info
    parent2_first_name: '',
    parent2_last_name: '',
    parent2_email: '',
    parent2_email_confirm: '', // Not saved, just for validation
    parent2_phone: '',
    // Program interest
    why_interested: '',
    is_local: '',
    local_area: '',
    referral_source: '',
    // Agreements
    agreements: {},
  });

  const handleChange = (field, value) => {
    if (field === 'parent_phone' || field === 'parent2_phone') {
      value = formatPhoneNumber(value);
    }
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  const handleAgreementChange = (key, checked) => {
    setFormData(prev => ({
      ...prev,
      agreements: { ...prev.agreements, [key]: checked },
    }));
  };

  const validateStep = (step) => {
    switch (step) {
      case 0: // Child Info
        if (!formData.child_first_name || !formData.child_last_name) {
          setError("Child's first and last name are required");
          return false;
        }
        if (!formData.child_date_of_birth) {
          setError("Child's date of birth is required");
          return false;
        }
        if (!formData.child_description) {
          setError("Please tell us about your child");
          return false;
        }
        break;
      case 1: // Parent Info
        // Parent 1 validation
        if (!formData.parent_first_name || !formData.parent_last_name) {
          setError("Parent/Guardian 1 first and last name are required");
          return false;
        }
        if (!formData.parent_email) {
          setError("Parent/Guardian 1 email is required");
          return false;
        }
        if (formData.parent_email !== formData.parent_email_confirm) {
          setError("Parent/Guardian 1 email addresses do not match");
          return false;
        }
        if (!formData.parent_phone) {
          setError("Parent/Guardian 1 phone number is required");
          return false;
        }
        // Parent 2 validation (optional, but validate email confirmation if provided)
        if (formData.parent2_email && formData.parent2_email !== formData.parent2_email_confirm) {
          setError("Parent/Guardian 2 email addresses do not match");
          return false;
        }
        break;
      case 2: // Program Interest
        if (!formData.why_interested) {
          setError("Please tell us what draws you to a nature-based preschool program for your child");
          return false;
        }
        if (!formData.is_local) {
          setError("Please indicate if your family is local to the area");
          return false;
        }
        if (!formData.referral_source) {
          setError("Please tell us how you learned about Earthkin's Nature Preschool");
          return false;
        }
        break;
      case 3: // Agreements
        const allAgreed = AGREEMENT_ITEMS.every(item => formData.agreements[item.key]);
        if (!allAgreed) {
          setError("Please acknowledge all items to continue");
          return false;
        }
        break;
    }
    setError(null);
    return true;
  };

  const handleNext = () => {
    if (validateStep(activeStep)) {
      setActiveStep(prev => prev + 1);
    }
  };

  const handleBack = () => {
    setError(null);
    setActiveStep(prev => prev - 1);
  };

  const handleSubmit = async () => {
    if (!validateStep(activeStep)) return;

    setError(null);
    setSubmitting(true);

    try {
      // Remove the email confirmation fields before sending
      const { parent_email_confirm, parent2_email_confirm, ...submitData } = formData;
      await enrollmentApplicationsApi.create(submitData);
      onSuccess?.();
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  };

  const renderStepContent = (step) => {
    switch (step) {
      case 0: // Child Info
        return (
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <Typography variant="body2" color="text.secondary" gutterBottom>
              Tell us about your child
            </Typography>
            <TextField
              label="Child's First Name"
              value={formData.child_first_name}
              onChange={(e) => handleChange('child_first_name', e.target.value)}
              required
              fullWidth
            />
            <TextField
              label="Child's Last Name"
              value={formData.child_last_name}
              onChange={(e) => handleChange('child_last_name', e.target.value)}
              required
              fullWidth
            />
            <TextField
              label="Child's Date of Birth"
              type="date"
              value={formData.child_date_of_birth}
              onChange={(e) => handleChange('child_date_of_birth', e.target.value)}
              fullWidth
              required
              slotProps={{ inputLabel: { shrink: true } }}
            />
            <TextField
              select
              label="Child's Race/Ethnicity"
              value={formData.child_race_ethnicity}
              onChange={(e) => handleChange('child_race_ethnicity', e.target.value)}
              fullWidth
              helperText="Optional"
            >
              <MenuItem value="">
                <em>Prefer not to say</em>
              </MenuItem>
              {RACE_ETHNICITY_OPTIONS.map((option) => (
                <MenuItem key={option} value={option}>
                  {option}
                </MenuItem>
              ))}
            </TextField>
            <TextField
              label="Please tell us about your child (temperament, interests, outdoor activity level, special needs, etc.)"
              value={formData.child_description}
              onChange={(e) => handleChange('child_description', e.target.value)}
              multiline
              rows={4}
              fullWidth
              required
            />
          </Box>
        );

      case 1: // Parent Info
        return (
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <Typography variant="body2" color="text.secondary" gutterBottom>
              Parent/Guardian Information
            </Typography>

            {/* Parent 1 */}
            <Typography variant="subtitle2" sx={{ mt: 1, fontWeight: 'bold' }}>
              Parent/Guardian 1
            </Typography>
            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField
                label="First Name"
                value={formData.parent_first_name}
                onChange={(e) => handleChange('parent_first_name', e.target.value)}
                required
                fullWidth
              />
              <TextField
                label="Last Name"
                value={formData.parent_last_name}
                onChange={(e) => handleChange('parent_last_name', e.target.value)}
                required
                fullWidth
              />
            </Box>
            <TextField
              label="Email"
              type="email"
              value={formData.parent_email}
              onChange={(e) => handleChange('parent_email', e.target.value)}
              required
              fullWidth
            />
            <TextField
              label="Please confirm your email"
              type="email"
              value={formData.parent_email_confirm}
              onChange={(e) => handleChange('parent_email_confirm', e.target.value)}
              required
              fullWidth
              error={formData.parent_email_confirm && formData.parent_email !== formData.parent_email_confirm}
              helperText={formData.parent_email_confirm && formData.parent_email !== formData.parent_email_confirm ? "Emails do not match" : ""}
            />
            <TextField
              label="Phone"
              value={formData.parent_phone}
              onChange={(e) => handleChange('parent_phone', e.target.value)}
              placeholder="(555) 123-4567"
              required
              fullWidth
            />

            {/* Parent 2 (Optional) */}
            <Typography variant="subtitle2" sx={{ mt: 2, fontWeight: 'bold' }}>
              Parent/Guardian 2 <Typography component="span" variant="body2" color="text.secondary">(Optional)</Typography>
            </Typography>
            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField
                label="First Name"
                value={formData.parent2_first_name}
                onChange={(e) => handleChange('parent2_first_name', e.target.value)}
                fullWidth
              />
              <TextField
                label="Last Name"
                value={formData.parent2_last_name}
                onChange={(e) => handleChange('parent2_last_name', e.target.value)}
                fullWidth
              />
            </Box>
            <TextField
              label="Email"
              type="email"
              value={formData.parent2_email}
              onChange={(e) => handleChange('parent2_email', e.target.value)}
              fullWidth
            />
            <TextField
              label="Please confirm your email"
              type="email"
              value={formData.parent2_email_confirm}
              onChange={(e) => handleChange('parent2_email_confirm', e.target.value)}
              fullWidth
              error={formData.parent2_email_confirm && formData.parent2_email !== formData.parent2_email_confirm}
              helperText={formData.parent2_email_confirm && formData.parent2_email !== formData.parent2_email_confirm ? "Emails do not match" : ""}
            />
            <TextField
              label="Phone"
              value={formData.parent2_phone}
              onChange={(e) => handleChange('parent2_phone', e.target.value)}
              placeholder="(555) 123-4567"
              fullWidth
            />
          </Box>
        );

      case 2: // Program Interest
        return (
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <Typography variant="body2" color="text.secondary" gutterBottom>
              Help us learn more about your family
            </Typography>
            <TextField
              label="What draws you to a nature-based preschool program for your child?"
              value={formData.why_interested}
              onChange={(e) => handleChange('why_interested', e.target.value)}
              multiline
              rows={4}
              fullWidth
              required
            />
            <TextField
              select
              label="Is your family local to the Swansboro neighborhood or southside Richmond?"
              value={formData.is_local}
              onChange={(e) => handleChange('is_local', e.target.value)}
              fullWidth
              required
            >
              {IS_LOCAL_OPTIONS.map((option) => (
                <MenuItem key={option.value} value={option.value}>
                  {option.label}
                </MenuItem>
              ))}
            </TextField>
            {(formData.is_local === 'no' || formData.is_local === 'not_sure') && (
              <TextField
                label="What general area of Richmond are you located in?"
                value={formData.local_area}
                onChange={(e) => handleChange('local_area', e.target.value)}
                fullWidth
              />
            )}
            <TextField
              select
              label="How did you learn about Earthkin's Nature Preschool?"
              value={formData.referral_source}
              onChange={(e) => handleChange('referral_source', e.target.value)}
              fullWidth
              required
            >
              {REFERRAL_SOURCE_OPTIONS.map((option) => (
                <MenuItem key={option} value={option}>
                  {option}
                </MenuItem>
              ))}
            </TextField>
          </Box>
        );

      case 3: // Agreements
        return (
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <Typography variant="body2" color="text.secondary" gutterBottom>
              Please review and acknowledge the following
            </Typography>
            <FormGroup>
              {AGREEMENT_ITEMS.map((item) => (
                <FormControlLabel
                  key={item.key}
                  control={
                    <Checkbox
                      checked={!!formData.agreements[item.key]}
                      onChange={(e) => handleAgreementChange(item.key, e.target.checked)}
                    />
                  }
                  label={
                    <Typography variant="body2" sx={{ lineHeight: 1.4 }}>
                      {item.label}
                    </Typography>
                  }
                  sx={{ alignItems: 'flex-start', mb: 1.5 }}
                />
              ))}
            </FormGroup>
            <FormHelperText>* All acknowledgments are required</FormHelperText>
          </Box>
        );

      default:
        return null;
    }
  };

  return (
    <Box>
      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      <Stepper activeStep={activeStep} sx={{ pt: 3, pb: 5 }}>
        {steps.map((label) => (
          <Step key={label}>
            <StepLabel>{label}</StepLabel>
          </Step>
        ))}
      </Stepper>

      {renderStepContent(activeStep)}

      <Box sx={{ display: 'flex', justifyContent: 'space-between', mt: 3 }}>
        {onCancel && <Button onClick={onCancel}>Cancel</Button>}
        <Box sx={{ flex: '1 1 auto' }} />
        {activeStep > 0 && (
          <Button onClick={handleBack}>Back</Button>
        )}
        {activeStep < steps.length - 1 ? (
          <Button variant="contained" onClick={handleNext} color="success">
            Next
          </Button>
        ) : (
          <Button
            variant="contained"
            onClick={handleSubmit}
            disabled={submitting}
            color="success"
          >
            {submitting ? 'Submitting...' : 'Submit Application'}
          </Button>
        )}
      </Box>
    </Box>
  );
}
