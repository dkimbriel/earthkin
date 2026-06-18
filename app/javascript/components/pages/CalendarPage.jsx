import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Box, Paper, Typography, CircularProgress, Chip, Stack } from "@mui/material";
import FullCalendar from "@fullcalendar/react";
import dayGridPlugin from "@fullcalendar/daygrid";
import interactionPlugin from "@fullcalendar/interaction";
import { programClassesApi, eventsApi } from "../../utils/api";

export default function CalendarPage() {
    const navigate = useNavigate();
    const [classes, setClasses] = useState([]);
    const [meetingEvents, setMeetingEvents] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
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
        loadData();
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

            let backgroundColor = "#4a7c59"; // Green for meet and greets
            let borderColor = "#3d6a4a";

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

            const childName = evt.eventable?.full_child_name || 'Unknown';
            const eventTypeLabel = evt.event_type === 'meet_and_greet' ? 'Meet & Greet' : evt.event_type;

            return {
                id: `event-${evt.id}`,
                title: `${eventTypeLabel}: ${childName}`,
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
            <Typography variant="h4" gutterBottom>
                Calendar
            </Typography>

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
            </Stack>

            <Paper sx={{
                p: 2,
                "& .fc-event": {
                    cursor: "pointer",
                },
            }}>
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
        </Box>
    );
}
