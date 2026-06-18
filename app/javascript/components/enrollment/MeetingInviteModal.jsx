import { useState, useEffect } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Box,
  Typography,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  TextField,
  IconButton,
  Alert,
  CircularProgress,
} from '@mui/material';
import { DateTimePicker } from '@mui/x-date-pickers/DateTimePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns';
import AddIcon from '@mui/icons-material/Add';
import DeleteIcon from '@mui/icons-material/Delete';
import { locationsApi, enrollmentApplicationsApi } from '../../utils/api';

export default function MeetingInviteModal({ open, onClose, application, onSuccess }) {
  const [locations, setLocations] = useState([]);
  const [locationId, setLocationId] = useState('');
  const [proposedDates, setProposedDates] = useState([null, null, null]);
  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [locationsLoading, setLocationsLoading] = useState(true);

  useEffect(() => {
    if (open) {
      loadLocations();
      // Reset form
      setProposedDates([null, null, null]);
      setNotes('');
      setError(null);
    }
  }, [open]);

  const loadLocations = async () => {
    try {
      setLocationsLoading(true);
      const data = await locationsApi.list();
      setLocations(data);
      // Auto-select first location if available
      if (data.length > 0) {
        setLocationId(data[0].id);
      }
    } catch (err) {
      setError('Failed to load locations');
    } finally {
      setLocationsLoading(false);
    }
  };

  const handleDateChange = (index, date) => {
    const newDates = [...proposedDates];
    newDates[index] = date;
    setProposedDates(newDates);
  };

  const handleAddDate = () => {
    if (proposedDates.length < 5) {
      setProposedDates([...proposedDates, null]);
    }
  };

  const handleRemoveDate = (index) => {
    if (proposedDates.length > 2) {
      const newDates = proposedDates.filter((_, i) => i !== index);
      setProposedDates(newDates);
    }
  };

  const handleSubmit = async () => {
    // Validate
    const validDates = proposedDates.filter(d => d !== null);
    if (validDates.length < 2) {
      setError('Please select at least 2 date options');
      return;
    }
    if (!locationId) {
      setError('Please select a location');
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Format dates as ISO strings
      const formattedDates = validDates.map(d => d.toISOString());

      await enrollmentApplicationsApi.sendMeetingInvite(application.id, {
        locationId,
        proposedDates: formattedDates,
        notes: notes || undefined,
      });

      onSuccess?.();
      onClose();
    } catch (err) {
      setError(err.message || 'Failed to send meeting invite');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Send Meeting Invite</DialogTitle>
      <DialogContent>
        <Box sx={{ pt: 1 }}>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
            Send {application?.parent_first_name} an email with date options for their meet-and-greet.
            They will click on their preferred date to confirm.
          </Typography>

          {error && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {error}
            </Alert>
          )}

          <FormControl fullWidth sx={{ mb: 3 }}>
            <InputLabel>Location</InputLabel>
            <Select
              value={locationId}
              onChange={(e) => setLocationId(e.target.value)}
              label="Location"
              disabled={locationsLoading}
            >
              {locations.map(location => (
                <MenuItem key={location.id} value={location.id}>
                  {location.name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          <Typography variant="subtitle2" sx={{ mb: 1 }}>
            Proposed Date Options ({proposedDates.length}/5)
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ mb: 2, display: 'block' }}>
            Select 2-5 date/time options for the parent to choose from
          </Typography>

          <LocalizationProvider dateAdapter={AdapterDateFns}>
            {proposedDates.map((date, index) => (
              <Box key={index} sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 1 }}>
                <DateTimePicker
                  label={`Option ${index + 1}`}
                  value={date}
                  onChange={(newDate) => handleDateChange(index, newDate)}
                  slotProps={{
                    textField: {
                      fullWidth: true,
                      size: 'small',
                    },
                  }}
                  minDate={new Date()}
                />
                {proposedDates.length > 2 && (
                  <IconButton
                    size="small"
                    onClick={() => handleRemoveDate(index)}
                    color="error"
                  >
                    <DeleteIcon />
                  </IconButton>
                )}
              </Box>
            ))}
          </LocalizationProvider>

          {proposedDates.length < 5 && (
            <Button
              startIcon={<AddIcon />}
              onClick={handleAddDate}
              size="small"
              sx={{ mb: 3 }}
            >
              Add Another Date Option
            </Button>
          )}

          <TextField
            label="Notes (optional)"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            multiline
            rows={2}
            fullWidth
            placeholder="Any additional notes for the parent..."
          />
        </Box>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={loading}>
          Cancel
        </Button>
        <Button
          onClick={handleSubmit}
          variant="contained"
          disabled={loading}
          startIcon={loading && <CircularProgress size={16} />}
        >
          {loading ? 'Sending...' : 'Send Meeting Invite'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
