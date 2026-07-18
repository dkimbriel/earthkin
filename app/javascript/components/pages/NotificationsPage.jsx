import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import {
	Box,
	Paper,
	Typography,
	Button,
	List,
	ListItemButton,
	ListItemIcon,
	ListItemText,
	Chip,
	Divider,
} from "@mui/material";
import EventIcon from "@mui/icons-material/Event";
import PaymentIcon from "@mui/icons-material/Payment";
import DescriptionIcon from "@mui/icons-material/Description";
import NotificationsIcon from "@mui/icons-material/Notifications";
import DoneAllIcon from "@mui/icons-material/DoneAll";
import { notificationsApi } from "../../utils/api";

const EVENT_ICON = {
	meeting_scheduled: <EventIcon />,
	payment_plan_selected: <PaymentIcon />,
	form_signed: <DescriptionIcon />,
};

export default function NotificationsPage() {
	const navigate = useNavigate();
	const [notifications, setNotifications] = useState([]);
	const [loading, setLoading] = useState(true);

	const load = async () => {
		setLoading(true);
		try {
			const data = await notificationsApi.list();
			setNotifications(data.notifications || []);
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		load();
	}, []);

	const handleClick = async (n) => {
		if (!n.read) {
			try {
				await notificationsApi.markRead(n.id);
				setNotifications((prev) => prev.map((x) => (x.id === n.id ? { ...x, read: true } : x)));
			} catch {
				/* non-blocking */
			}
		}
		if (n.enrollment_application_id) {
			navigate(`/enrollment-applications/${n.enrollment_application_id}`);
		}
	};

	const handleMarkAllRead = async () => {
		await notificationsApi.markAllRead();
		setNotifications((prev) => prev.map((x) => ({ ...x, read: true })));
	};

	const unreadCount = notifications.filter((n) => !n.read).length;

	return (
		<Box>
			<Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 2 }}>
				<Typography variant="h5" component="h1">
					Notifications
					{unreadCount > 0 && (
						<Chip label={`${unreadCount} unread`} color="primary" size="small" sx={{ ml: 1.5 }} />
					)}
				</Typography>
				<Button
					startIcon={<DoneAllIcon />}
					onClick={handleMarkAllRead}
					disabled={unreadCount === 0}
				>
					Mark all read
				</Button>
			</Box>

			<Paper variant="outlined">
				{loading ? (
					<Typography sx={{ p: 3 }} color="text.secondary">Loading...</Typography>
				) : notifications.length === 0 ? (
					<Box sx={{ p: 5, textAlign: "center", color: "text.secondary" }}>
						<NotificationsIcon sx={{ fontSize: 48, opacity: 0.4 }} />
						<Typography sx={{ mt: 1 }}>No notifications yet.</Typography>
						<Typography variant="body2">
							You'll be alerted here when a family schedules a meet &amp; greet, selects a payment plan, or signs an enrollment form.
						</Typography>
					</Box>
				) : (
					<List disablePadding>
						{notifications.map((n, i) => (
							<Box key={n.id}>
								{i > 0 && <Divider component="li" />}
								<ListItemButton
									onClick={() => handleClick(n)}
									sx={{ bgcolor: n.read ? "background.paper" : "action.hover", py: 1.5 }}
								>
									<ListItemIcon sx={{ color: n.read ? "text.disabled" : "primary.main" }}>
										{EVENT_ICON[n.event_type] || <NotificationsIcon />}
									</ListItemIcon>
									<ListItemText
										primary={n.title}
										secondary={n.body}
										primaryTypographyProps={{ fontWeight: n.read ? 400 : 600 }}
									/>
									<Typography variant="caption" color="text.secondary" sx={{ whiteSpace: "nowrap", ml: 2 }}>
										{new Date(n.created_at).toLocaleString()}
									</Typography>
								</ListItemButton>
							</Box>
						))}
					</List>
				)}
			</Paper>
		</Box>
	);
}
