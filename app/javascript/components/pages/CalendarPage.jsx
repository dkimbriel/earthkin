import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import {
    Box,
    Paper,
    Typography,
    CircularProgress,
    Chip,
    Stack,
    Button,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    MenuItem,
    FormControlLabel,
    Switch,
    Alert,
} from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import FullCalendar from "@fullcalendar/react";
import dayGridPlugin from "@fullcalendar/daygrid";
import interactionPlugin from "@fullcalendar/interaction";
import { programClassesApi, eventsApi, locationsApi } from "../../utils/api";
import { useAuth } from "../../contexts/AuthContext";

const EVENT_TYPE_OPTIONS = [
    { value: "open_house", label: "Open House" },
    { value: "field_trip", label: "Field Trip" },
    { value: "parent_meeting", label: "Parent Meeting" },
    { value: "orientation", label: "Orientation" },
    { value: "other", label: "Other" },
];

const EMPTY_EVENT = {
    title: "",
    event_type: "other",
    scheduled_at: "",
    location_id: "",
    description: "",
    published: false,
};

// datetime-local inputs want "YYYY-MM-DDTHH:MM" in local time.
const toLocalInput = (iso) => {
    if (!iso) return "";
    const d = new Date(iso);
    const pad = (n) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

function EventDialog({ open, onClose, onSubmit, onCancelEvent, initial, locations, title }) {
    const [form, setForm] = useState(
        initial
            ? { ...EMPTY_EVENT, ...initial, scheduled_at: toLocalInput(initial.scheduled_at), location_id: initial.location_id || "" }
            : EMPTY_EVENT
    );
    const [error, setError] = useState(null);
    const [submitting, setSubmitting] = useState(false);

    const set = (name, value) => setForm((prev) => ({ ...prev, [name]: value }));

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError(null);
        setSubmitting(true);
        try {
            await onSubmit({
                title: form.title,
                event_type: form.event_type,
                scheduled_at: form.scheduled_at,
                location_id: form.location_id || null,
                description: form.description,
                published: form.published,
            });
            onClose();
        } catch (err) {
            setError(err.message);
        } finally {
            setSubmitting(false);
        }
    };

    return (
        <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
            <form onSubmit={handleSubmit}>
                <DialogTitle>{title}</DialogTitle>
                <DialogContent>
                    {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                    <Box sx={{ display: "flex", flexDirection: "column", gap: 2, mt: 1 }}>
                        <TextField
                            label="Title"
                            value={form.title}
                            onChange={(e) => set("title", e.target.value)}
                            required
                            fullWidth
                        />
                        <TextField
                            select
                            label="Event Type"
                            value={form.event_type}
                            onChange={(e) => set("event_type", e.target.value)}
                            fullWidth
                        >
                            {EVENT_TYPE_OPTIONS.map((o) => (
                                <MenuItem key={o.value} value={o.value}>{o.label}</MenuItem>
                            ))}
                        </TextField>
                        <TextField
                            label="Date & Time"
                            type="datetime-local"
                            value={form.scheduled_at}
                            onChange={(e) => set("scheduled_at", e.target.value)}
                            required
                            fullWidth
                            slotProps={{ inputLabel: { shrink: true } }}
                        />
                        <TextField
                            select
                            label="Location"
                            value={form.location_id}
                            onChange={(e) => set("location_id", e.target.value)}
                            fullWidth
                        >
                            <MenuItem value="">None</MenuItem>
                            {locations.map((l) => (
                                <MenuItem key={l.id} value={l.id}>{l.name}</MenuItem>
                            ))}
                        </TextField>
                        <TextField
                            label="Description"
                            value={form.description || ""}
                            onChange={(e) => set("description", e.target.value)}
                            multiline
                            rows={2}
                            fullWidth
                        />
                        <FormControlLabel
                            control={
                                <Switch
                                    checked={form.published}
                                    onChange={(e) => set("published", e.target.checked)}
                                />
                            }
                            label="Publish to parent portal calendar"
                        />
                    </Box>
                </DialogContent>
                <DialogActions sx={{ justifyContent: "space-between", px: 3 }}>
                    <Box>
                        {onCancelEvent && (
                            <Button color="error" onClick={onCancelEvent}>
                                Cancel Event
                            </Button>
                        )}
                    </Box>
                    <Box>
                        <Button onClick={onClose}>Close</Button>
                        <Button type="submit" variant="contained" disabled={submitting}>
                            {submitting ? "Saving..." : "Save"}
                        </Button>
                    </Box>
                </DialogActions>
            </form>
        </Dialog>
    );
}

export default function CalendarPage() {
    const navigate = useNavigate();
    const { user } = useAuth();
    const isAdmin = user?.role === "admin";
    const [classes, setClasses] = useState([]);
    const [meetingEvents, setMeetingEvents] = useState([]);
    const [locations, setLocations] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showForm, setShowForm] = useState(false);
    const [editTarget, setEditTarget] = useState(null);

    const loadData = async () => {
        try {
            const [classData, eventData] = await Promise.all([
                programClassesApi.list(),
                eventsApi.list()
            ]);
            setClasses(classData);
            setMeetingEvents(eventData);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadData();
        locationsApi.list().then(setLocations).catch(() => {});
    }, []);

    // Map program classes to calendar events
    const classEvents = classes.map((cls) => {
        const isComplete = cls.date && new Date(cls.date) < new Date().setHours(0, 0, 0, 0);
        return {
            id: `class-${cls.id}`,
            title: `${cls.program?.name}: ${cls.name}`,
            date: cls.date,
            backgroundColor: isComplete ? "#9e9e9e" : "#1976d2",
            borderColor: isComplete ? "#757575" : "#1565c0",
            classNames: isComplete ? ["fc-event-past"] : [],
            extendedProps: {
                type: 'class',
                programClass: cls,
                isComplete,
            },
        };
    });

    // Map meeting events to calendar events (only those with scheduled_at)
    const meetingCalendarEvents = meetingEvents
        .filter(evt => evt.scheduled_at) // Only show events that have a confirmed date
        .map((evt) => {
            const isPast = new Date(evt.scheduled_at) < new Date();
            const isCompleted = evt.status === 'completed';
            const isCancelled = evt.status === 'cancelled';
            const isManual = !evt.eventable_type;

            let backgroundColor = isManual ? "#7b1fa2" : "#4a7c59"; // Purple school events, green meet & greets
            let borderColor = isManual ? "#6a1b9a" : "#3d6a4a";

            if (isCancelled) {
                backgroundColor = "#d32f2f";
                borderColor = "#b71c1c";
            } else if (isCompleted) {
                backgroundColor = "#388e3c";
                borderColor = "#2e7d32";
            } else if (isPast) {
                backgroundColor = "#9e9e9e";
                borderColor = "#757575";
            }

            let displayTitle;
            if (isManual) {
                displayTitle = evt.published ? `${evt.title} ★` : evt.title;
            } else {
                const childName = evt.eventable?.full_child_name || 'Unknown';
                const eventTypeLabel = evt.event_type === 'meet_and_greet' ? 'Meet & Greet' : evt.event_type;
                displayTitle = `${eventTypeLabel}: ${childName}`;
            }

            return {
                id: `event-${evt.id}`,
                title: displayTitle,
                start: evt.scheduled_at,
                backgroundColor,
                borderColor,
                extendedProps: {
                    type: 'event',
                    event: evt,
                    isCompleted,
                    isCancelled,
                },
            };
        });

    const allCalendarEvents = [...classEvents, ...meetingCalendarEvents];

    const handleEventClick = (info) => {
        const { type, programClass, event } = info.event.extendedProps;

        if (type === 'class') {
            navigate(`/classes/${programClass.id}/edit`, { state: { from: "/calendar" } });
        } else if (type === 'event' && event.eventable_type === 'EnrollmentApplication') {
            navigate(`/enrollment-applications/${event.eventable_id}`);
        } else if (type === 'event' && !event.eventable_type && isAdmin) {
            setEditTarget(event);
        }
    };

    if (loading) {
        return (
            <Box sx={{ display: "flex", justifyContent: "center", py: 4 }}>
                <CircularProgress />
            </Box>
        );
    }

    return (
        <Box>
            <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <Typography variant="h4" gutterBottom>
                    Calendar
                </Typography>
                {isAdmin && (
                    <Button variant="contained" startIcon={<AddIcon />} onClick={() => setShowForm(true)}>
                        Add Event
                    </Button>
                )}
            </Box>

            {/* Legend */}
            <Stack direction="row" spacing={2} sx={{ mb: 2 }}>
                <Chip
                    size="small"
                    label="Classes"
                    sx={{ backgroundColor: "#1976d2", color: "white" }}
                />
                <Chip
                    size="small"
                    label="Meet & Greets"
                    sx={{ backgroundColor: "#4a7c59", color: "white" }}
                />
                <Chip
                    size="small"
                    label="School Events (★ = on parent calendar)"
                    sx={{ backgroundColor: "#7b1fa2", color: "white" }}
                />
            </Stack>

            <Paper sx={(theme) => ({
                p: 2,
                "& .fc-event": {
                    cursor: "pointer",
                },
                // Theme FullCalendar's toolbar buttons to match the app's green
                // palette instead of its off-theme default navy/grey.
                "& .fc": {
                    "--fc-button-bg-color": theme.palette.primary.main,
                    "--fc-button-border-color": theme.palette.primary.main,
                    "--fc-button-hover-bg-color": theme.palette.primary.dark,
                    "--fc-button-hover-border-color": theme.palette.primary.dark,
                    "--fc-button-active-bg-color": theme.palette.primary.dark,
                    "--fc-button-active-border-color": theme.palette.primary.dark,
                    "--fc-button-text-color": theme.palette.primary.contrastText,
                },
                "& .fc .fc-button": {
                    textTransform: "capitalize",
                    boxShadow: "none",
                    fontWeight: 500,
                },
                "& .fc .fc-button:focus, & .fc .fc-button:focus-visible": {
                    boxShadow: `0 0 0 2px ${theme.palette.primary.light}`,
                },
            })}>
                <FullCalendar
                    plugins={[dayGridPlugin, interactionPlugin]}
                    initialView="dayGridMonth"
                    events={allCalendarEvents}
                    eventClick={handleEventClick}
                    headerToolbar={{
                        left: "prev,next today",
                        center: "title",
                        right: "dayGridMonth,dayGridWeek",
                    }}
                    height="auto"
                    eventDisplay="block"
                    dayMaxEvents={3}
                />
            </Paper>

            {showForm && (
                <EventDialog
                    open={showForm}
                    onClose={() => setShowForm(false)}
                    onSubmit={async (form) => {
                        await eventsApi.create(form);
                        loadData();
                    }}
                    locations={locations}
                    title="Add School Event"
                />
            )}

            {editTarget && (
                <EventDialog
                    key={editTarget.id}
                    onClose={() => setEditTarget(null)}
                    open={!!editTarget}
                    onSubmit={async (form) => {
                        await eventsApi.update(editTarget.id, form);
                        setEditTarget(null);
                        loadData();
                    }}
                    onCancelEvent={async () => {
                        await eventsApi.cancel(editTarget.id);
                        setEditTarget(null);
                        loadData();
                    }}
                    initial={editTarget}
                    locations={locations}
                    title="Edit School Event"
                />
            )}
        </Box>
    );
}
