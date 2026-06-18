import { useState } from 'react';
import { Box, Typography, Chip, Paper, Button, Tooltip, Dialog, DialogTitle, DialogContent, DialogActions, IconButton } from '@mui/material';
import Timeline from '@mui/lab/Timeline';
import TimelineItem from '@mui/lab/TimelineItem';
import TimelineSeparator from '@mui/lab/TimelineSeparator';
import TimelineConnector from '@mui/lab/TimelineConnector';
import TimelineContent from '@mui/lab/TimelineContent';
import TimelineDot from '@mui/lab/TimelineDot';
import TimelineOppositeContent from '@mui/lab/TimelineOppositeContent';
import EmailIcon from '@mui/icons-material/Email';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import ErrorIcon from '@mui/icons-material/Error';
import ScheduleIcon from '@mui/icons-material/Schedule';
import VisibilityIcon from '@mui/icons-material/Visibility';
import MeetingInviteModal from './MeetingInviteModal';

const formatStatusLabel = (status) => {
  return status
    .replace(/_/g, ' ')
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
};

export default function EmailTimeline({ emails, application, onSendEmail, onRefresh }) {
  const [selectedEmail, setSelectedEmail] = useState(null);
  const [showEmailDialog, setShowEmailDialog] = useState(false);
  const [showMeetingInviteModal, setShowMeetingInviteModal] = useState(false);

  const handleViewEmail = (email) => {
    setSelectedEmail(email);
    setShowEmailDialog(true);
  };

  const handleCloseDialog = () => {
    setShowEmailDialog(false);
    setSelectedEmail(null);
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'sent':
        return <CheckCircleIcon />;
      case 'failed':
      case 'bounced':
        return <ErrorIcon />;
      case 'queued':
        return <ScheduleIcon />;
      default:
        return <EmailIcon />;
    }
  };

  const emailTypes = application ? [
    {
      type: 'enrollment_invite',
      label: 'Enrollment Invite',
      description: 'Invitation to apply for the program',
      enabled: application.status === 'invited'
    },
    {
      type: 'meeting_invite',
      label: 'Meeting Invite',
      description: 'Send date options for meet-n-greet',
      enabled: ['submitted', 'reviewed'].includes(application.status),
      isModal: true
    },
    {
      type: 'meeting_scheduled',
      label: 'Meeting Scheduled',
      description: 'Meet-n-greet confirmation',
      enabled: ['reviewed', 'meeting_scheduled', 'meeting_completed', 'fee_requested', 'fee_paid', 'enrolled'].includes(application.status) &&
               application.events?.some(e => e.event_type === 'meet_and_greet' && e.status === 'scheduled')
    },
    {
      type: 'enrollment_fee_request',
      label: 'Fee Request',
      description: 'Enrollment fee payment instructions',
      enabled: ['meeting_completed', 'fee_requested', 'fee_paid', 'enrolled'].includes(application.status)
    },
    {
      type: 'enrollment_confirmed',
      label: 'Enrollment Confirmed',
      description: 'Final enrollment confirmation',
      enabled: application.status === 'enrolled'
    }
  ] : [];

  const handleEmailAction = (emailType) => {
    if (emailType.isModal && emailType.type === 'meeting_invite') {
      setShowMeetingInviteModal(true);
    } else {
      onSendEmail(emailType.type);
    }
  };

  const handleMeetingInviteSuccess = () => {
    onRefresh?.();
  };

  return (
    <>
      {!emails || emails.length === 0 ? (
        <Paper sx={{ p: 3, textAlign: 'center', bgcolor: 'grey.50', mb: 2 }}>
          <Typography color="text.secondary">
            No emails sent yet
          </Typography>
        </Paper>
      ) : (
        <Timeline position="right">
          {emails.map((email, index) => (
            <TimelineItem key={email.id}>
              <TimelineOppositeContent color="text.secondary" sx={{ flex: 0.3 }}>
                <Typography variant="caption">
                  {email.sent_at
                    ? new Date(email.sent_at).toLocaleString()
                    : new Date(email.created_at).toLocaleString()}
                </Typography>
              </TimelineOppositeContent>

              <TimelineSeparator>
                <TimelineDot color={email.status_color}>
                  {getStatusIcon(email.status)}
                </TimelineDot>
                {index < emails.length - 1 && <TimelineConnector />}
              </TimelineSeparator>

              <TimelineContent>
                <Paper elevation={1} sx={{ p: 2 }}>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                    <Typography variant="subtitle2" fontWeight="bold">
                      {email.type_label}
                    </Typography>
                    <Chip
                      label={formatStatusLabel(email.status)}
                      color={email.status_color}
                      size="small"
                    />
                  </Box>
                  <Typography variant="body2" color="text.secondary">
                    {email.subject}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    To: {email.recipient}
                  </Typography>
                  {email.failed_at && email.error_message && (
                    <Typography variant="caption" color="error" sx={{ display: 'block', mt: 1 }}>
                      Error: {email.error_message}
                    </Typography>
                  )}
                  {email.html_body && (
                    <Box sx={{ display: 'flex', justifyContent: 'flex-start', mt: 2 }}>
                      <Button
                        size="small"
                        variant="outlined"
                        startIcon={<VisibilityIcon />}
                        onClick={() => handleViewEmail(email)}
                      >
                        View
                      </Button>
                    </Box>
                  )}
                </Paper>
              </TimelineContent>
            </TimelineItem>
          ))}
        </Timeline>
      )}

      {application && onSendEmail && (
        <Paper sx={{ p: 2, mt: 2, bgcolor: 'grey.50' }}>
          <Typography variant="subtitle2" gutterBottom>
            Manual Email Actions
          </Typography>
          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 2 }}>
            Resend or manually trigger emails to the parent
          </Typography>
          <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
            {emailTypes.map(email => (
              <Tooltip
                key={email.type}
                title={email.enabled ? email.description : 'Not available for current status'}
              >
                <span>
                  <Button
                    size="small"
                    variant="outlined"
                    startIcon={<EmailIcon />}
                    onClick={() => handleEmailAction(email)}
                    disabled={!email.enabled}
                  >
                    {email.label}
                  </Button>
                </span>
              </Tooltip>
            ))}
          </Box>
        </Paper>
      )}

      {/* Meeting Invite Modal */}
      <MeetingInviteModal
        open={showMeetingInviteModal}
        onClose={() => setShowMeetingInviteModal(false)}
        application={application}
        onSuccess={handleMeetingInviteSuccess}
      />

      {/* Email Preview Dialog */}
      <Dialog
        open={showEmailDialog}
        onClose={handleCloseDialog}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          Email Preview: {selectedEmail?.type_label}
        </DialogTitle>
        <DialogContent>
          <Box sx={{ mb: 2 }}>
            <Typography variant="caption" color="text.secondary">
              <strong>Subject:</strong> {selectedEmail?.subject}
            </Typography>
            <br />
            <Typography variant="caption" color="text.secondary">
              <strong>To:</strong> {selectedEmail?.recipient}
            </Typography>
            <br />
            <Typography variant="caption" color="text.secondary">
              <strong>Sent:</strong> {selectedEmail?.sent_at
                ? new Date(selectedEmail.sent_at).toLocaleString()
                : 'Not sent yet'}
            </Typography>
          </Box>
          {selectedEmail?.html_body && (
            <Box
              sx={{
                border: '1px solid #ddd',
                borderRadius: 1,
                p: 2,
                bgcolor: 'white',
                maxHeight: '500px',
                overflow: 'auto'
              }}
              dangerouslySetInnerHTML={{
                __html: selectedEmail.html_body.replace(/cid:[^"']*/g, '/logo.png')
              }}
            />
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Close</Button>
        </DialogActions>
      </Dialog>
    </>
  );
}
