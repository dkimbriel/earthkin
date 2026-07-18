import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Box, Chip, Tabs, Tab } from '@mui/material';
import DataTable from '../shared/DataTable';
import PageHeader from '../shared/PageHeader';
import { enrollmentApplicationsApi } from '../../utils/api';

const statusColors = {
  invited: 'default',
  submitted: 'info',
  reviewed: 'primary',
  meeting_scheduled: 'secondary',
  meeting_completed: 'success',
  fee_requested: 'warning',
  fee_paid: 'success',
  signing_docs: 'info',
  enrolled: 'success',
  declined: 'error',
};

const formatStatusLabel = (status) => {
  return status
    .replace(/_/g, ' ')
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
};

const columns = [
  {
    key: 'full_parent_name',
    label: 'Parent',
  },
  {
    key: 'full_child_name',
    label: 'Child',
  },
  {
    key: 'program',
    label: 'Program',
    render: (row) => row.program?.name || '—',
  },
  {
    key: 'status',
    label: 'Status',
    render: (row) => (
      <Chip
        label={formatStatusLabel(row.status)}
        color={statusColors[row.status] || 'default'}
        size="small"
      />
    ),
  },
  {
    key: 'selected_payment_plan',
    label: 'Payment Plan',
    render: (row) => row.selected_payment_plan ? (
      <Chip
        label={row.selected_payment_plan.name}
        color="success"
        size="small"
      />
    ) : (
      <Chip label="Not selected" variant="outlined" size="small" />
    ),
  },
  {
    key: 'submitted_at',
    label: 'Submitted',
    render: (row) => row.submitted_at ?
      new Date(row.submitted_at).toLocaleDateString() : '—',
  },
];

export default function EnrollmentApplicationsPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const [applications, setApplications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [counts, setCounts] = useState({});

  const statusFilter = searchParams.get('status') || 'all';

  useEffect(() => {
    loadCounts();
  }, []);

  useEffect(() => {
    loadApplications();
  }, [statusFilter]);

  const loadCounts = async () => {
    try {
      const data = await enrollmentApplicationsApi.counts();
      setCounts(data);
    } catch (error) {
      console.error('Failed to load counts:', error);
    }
  };

  const loadApplications = async () => {
    setLoading(true);
    try {
      const filters = statusFilter !== 'all' ? { status: statusFilter } : {};
      const data = await enrollmentApplicationsApi.list(filters);
      setApplications(data);
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = (event, newValue) => {
    if (newValue === 'all') {
      setSearchParams({});
    } else {
      setSearchParams({ status: newValue });
    }
  };

  const getTabLabel = (label, status) => {
    const count = counts[status];
    return (
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        {label}
        {count !== undefined && (
          <Chip label={count} size="small" sx={{ height: 20, minWidth: 20, '& .MuiChip-label': { px: 0.75 } }} />
        )}
      </Box>
    );
  };

  return (
    <Box>
      <PageHeader title="Enrollment Applications" />

      <Tabs value={statusFilter} onChange={handleStatusChange} sx={{ mb: 3 }}>
        <Tab label={getTabLabel("All", "all")} value="all" sx={{ textTransform: 'none' }} />
        <Tab label={getTabLabel("Invited", "invited")} value="invited" sx={{ textTransform: 'none' }} />
        <Tab label={getTabLabel("Submitted", "submitted")} value="submitted" sx={{ textTransform: 'none' }} />
        <Tab label={getTabLabel("Reviewed", "reviewed")} value="reviewed" sx={{ textTransform: 'none' }} />
        <Tab label={getTabLabel("Meeting Scheduled", "meeting_scheduled")} value="meeting_scheduled" sx={{ textTransform: 'none' }} />
        <Tab label={getTabLabel("Fee Requested", "fee_requested")} value="fee_requested" sx={{ textTransform: 'none' }} />
        <Tab label={getTabLabel("Signing Docs", "signing_docs")} value="signing_docs" sx={{ textTransform: 'none' }} />
        <Tab label={getTabLabel("Enrolled", "enrolled")} value="enrolled" sx={{ textTransform: 'none' }} />
      </Tabs>

      <DataTable
        columns={columns}
        data={applications}
        loading={loading}
        onRowClick={(row) => navigate(`/enrollment-applications/${row.id}`)}
        emptyMessage="No applications found."
      />
    </Box>
  );
}
