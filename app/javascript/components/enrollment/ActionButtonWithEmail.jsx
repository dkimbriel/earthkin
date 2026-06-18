import { Button, Tooltip, Box } from '@mui/material';
import EmailIcon from '@mui/icons-material/Email';

export default function ActionButtonWithEmail({
  children,
  emailDescription,
  onClick,
  ...buttonProps
}) {
  const button = (
    <Button onClick={onClick} {...buttonProps}>
      {children}
    </Button>
  );

  if (!emailDescription) {
    return button;
  }

  return (
    <Box sx={{ position: 'relative', display: 'inline-block' }}>
      <Tooltip
        title={
          <Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 0.5 }}>
              <EmailIcon fontSize="small" />
              <strong>Email will be sent:</strong>
            </Box>
            {emailDescription}
          </Box>
        }
        arrow
        placement="top"
      >
        {button}
      </Tooltip>
    </Box>
  );
}
