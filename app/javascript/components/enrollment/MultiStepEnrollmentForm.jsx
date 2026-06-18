import {
  Dialog,
  DialogTitle,
  DialogContent,
} from '@mui/material';
import EnrollmentFormContent from './EnrollmentFormContent';

export default function MultiStepEnrollmentForm({ open, onClose, programId, onSuccess }) {
  const handleSuccess = () => {
    onSuccess?.();
    onClose();
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle>Enrollment Application</DialogTitle>
      <DialogContent>
        <EnrollmentFormContent
          programId={programId}
          onSuccess={handleSuccess}
          onCancel={onClose}
        />
      </DialogContent>
    </Dialog>
  );
}
