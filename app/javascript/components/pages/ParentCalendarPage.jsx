import { useState, useEffect } from "react";
import { Box, Paper, Typography, CircularProgress, Chip, Stack, Alert } from "@mui/material";
import FullCalendar from "@fullcalendar/react";
import dayGridPlugin from "@fullcalendar/daygrid";
import { portalApi } from "../../utils/api";

export default function ParentCalendarPage() {
    const [data, setData] = useState(null);
    const [error, setError] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        portalApi
            .events()
            .then(setData)
            .catch((err) => setError(err.message))
            .finally(() => setLoading(false));
    }, []);

    if (loading) {
        return (
            <Box sx={{ display: "flex", justifyContent: "center", py: 6 }}>
                <CircularProgress />
            </Box>
        );
    }

    if (error) {
        return <Alert severity="error">{error}</Alert>;
    }

    const classEvents = data.classes.map((cls) => ({
        id: `class-${cls.id}`,
        title: cls.title,
        date: cls.date,
        backgroundColor: "#1976d2",
        borderColor: "#1565c0",
    }));

    const schoolEvents = data.events.map((evt) => ({
        id: `event-${evt.id}`,
        title: evt.location ? `${evt.title} @ ${evt.location}` : evt.title,
        start: evt.scheduled_at,
        backgroundColor: "#7b1fa2",
        borderColor: "#6a1b9a",
    }));

    return (
        <Box>
            <Typography variant="h4" gutterBottom>
                Calendar
            </Typography>

            <Stack direction="row" spacing={2} sx={{ mb: 2 }}>
                <Chip size="small" label="Class Days" sx={{ backgroundColor: "#1976d2", color: "white" }} />
                <Chip size="small" label="School Events" sx={{ backgroundColor: "#7b1fa2", color: "white" }} />
            </Stack>

            <Paper sx={(theme) => ({
                p: 2,
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
                    plugins={[dayGridPlugin]}
                    initialView="dayGridMonth"
                    events={[...classEvents, ...schoolEvents]}
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
