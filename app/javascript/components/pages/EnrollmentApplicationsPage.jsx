import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Box, Chip, Tabs, Tab } from '@mui/material';
import DataTable from '../shared/DataTable';
import PageHeader from '../shared/PageHeader';
import SearchField from '../shared/SearchField';
import ListPagination from '../shared/ListPagination';
import { enrollmentApplicationsApi } from '../../utils/api';
import usePagedList from '../../utils/usePagedList';

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
  const [counts, setCounts] = useState({});

  const statusFilter = searchParams.get('status') || 'all';
  const list = usePagedList(enrollmentApplicationsApi.list, {
    filters: statusFilter !== 'all' ? { status: statusFilter } : {},
  });

  useEffect(() => {
    loadCounts();
  }, []);

  const loadCounts = async () => {
    try {
      const data = await enrollmentApplicationsApi.counts();
      setCounts(data);
    } catch (error) {
      console.error('Failed to load counts:', error);
    }
  };

  // Switching status keeps any search (?q=) and starts again at page 1.
  const handleStatusChange = (event, newValue) => {
    const next = new URLSearchParams(searchParams);
    if (newValue === 'all') next.delete('status');
    else next.set('status', newValue);
    next.delete('page');
    setSearchParams(next);
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
        <Tab label={getTabLabel("Declined", "declined")} value="declined" sx={{ textTransform: 'none' }} />
      </Tabs>

      <SearchField
        value={list.query}
        onChange={list.setQuery}
        placeholder="Search child, parent, email, program"
        total={list.total}
        noun="applications"
      />

      <DataTable
        columns={columns}
        data={list.rows}
        loading={list.initialLoading}
        onRowClick={(row) => navigate(`/enrollment-applications/${row.id}`)}
        emptyMessage={list.query ? `No applications match "${list.query}".` : 'No applications found.'}
      />
      <ListPagination list={list} />
    </Box>
  );
}
