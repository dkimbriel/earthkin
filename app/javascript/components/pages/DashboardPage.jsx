import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import {
	Box,
	Typography,
	Paper,
	Table,
	TableBody,
	TableCell,
	TableContainer,
	TableHead,
	TableRow,
	Collapse,
	IconButton,
} from "@mui/material";
import KeyboardArrowDownIcon from "@mui/icons-material/KeyboardArrowDown";
import KeyboardArrowUpIcon from "@mui/icons-material/KeyboardArrowUp";
import { reportsApi } from "../../utils/api";
import EarthkinLoader from "../shared/EarthkinLoader";

function WeekRow({ week, navigate }) {
	const [open, setOpen] = useState(false);

	const formatDate = (dateStr) => {
		if (!dateStr) return "";
		const [year, month, day] = dateStr.split("-");
		return new Date(year, month - 1, day).toLocaleDateString("en-US", {
			month: "short",
			day: "numeric",
		});
	};

	const formatWeekRange = (start, end) => {
		const startDate = formatDate(start);
		const endDate = formatDate(end);
		return `${startDate} - ${endDate}`;
	};

	const isCurrentWeek = () => {
		const today = new Date();
		const weekStart = new Date(week.week_start);
		const weekEnd = new Date(week.week_end);
		weekEnd.setHours(23, 59, 59);
		return today >= weekStart && today <= weekEnd;
	};

	return (
		<>
			<TableRow
				sx={{
					"& > *": { borderBottom: "unset" },
					backgroundColor: isCurrentWeek() ? "action.selected" : "inherit",
				}}
			>
				<TableCell>
					<IconButton size="small" onClick={() => setOpen(!open)}>
						{open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />}
					</IconButton>
				</TableCell>
				<TableCell>
					<Typography fontWeight={isCurrentWeek() ? "bold" : "normal"}>
						{formatWeekRange(week.week_start, week.week_end)}
						{isCurrentWeek() && " (This Week)"}
					</Typography>
				</TableCell>
				<TableCell align="center">{week.class_count}</TableCell>
				<TableCell align="right">
					<Typography fontWeight="medium" color="success.main">
						${parseFloat(week.revenue).toFixed(2)}
					</Typography>
				</TableCell>
			</TableRow>
			<TableRow>
				<TableCell style={{ paddingBottom: 0, paddingTop: 0 }} colSpan={4}>
					<Collapse in={open} timeout="auto" unmountOnExit>
						<Box sx={{ margin: 2 }}>
							<Typography variant="subtitle2" gutterBottom>
								Classes
							</Typography>
							<Table size="small">
								<TableHead>
									<TableRow>
										<TableCell>Date</TableCell>
										<TableCell>Class</TableCell>
										<TableCell>Program</TableCell>
										<TableCell align="right">Revenue</TableCell>
									</TableRow>
								</TableHead>
								<TableBody>
									{week.classes.map((cls) => (
										<TableRow
											key={cls.id}
											hover
											sx={{ cursor: "pointer" }}
											onClick={() => navigate(`/programs/${cls.program_id}`)}
										>
											<TableCell>{formatDate(cls.date)}</TableCell>
											<TableCell>{cls.name}</TableCell>
											<TableCell>{cls.program_name}</TableCell>
											<TableCell align="right">
												${parseFloat(cls.revenue).toFixed(2)}
											</TableCell>
										</TableRow>
									))}
								</TableBody>
							</Table>
						</Box>
					</Collapse>
				</TableCell>
			</TableRow>
		</>
	);
}

export default function DashboardPage() {
	const navigate = useNavigate();
	const [weeklyData, setWeeklyData] = useState([]);
	const [loading, setLoading] = useState(true);

	useEffect(() => {
		const loadData = async () => {
			setLoading(true);
			try {
				const data = await reportsApi.weeklyRevenue();
				setWeeklyData(data);
			} finally {
				setLoading(false);
			}
		};
		loadData();
	}, []);

	const totalRevenue = weeklyData.reduce(
		(sum, week) => sum + parseFloat(week.revenue || 0),
		0
	);

	if (loading) {
		return (
			<Box sx={{ display: "flex", justifyContent: "center", p: 4 }}>
				<EarthkinLoader />
			</Box>
		);
	}

	return (
		<Box>
			<Typography variant="h4" gutterBottom>
				Dashboard
			</Typography>

			<Paper sx={{ p: 3, mb: 3 }}>
				<Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 2 }}>
					<Typography variant="h6">Weekly Revenue Forecast</Typography>
					<Typography variant="h6" color="success.main">
						Total: ${totalRevenue.toFixed(2)}
					</Typography>
				</Box>

				{weeklyData.length === 0 ? (
					<Typography color="text.secondary">
						No scheduled classes found in the next 12 weeks.
					</Typography>
				) : (
					<TableContainer>
						<Table>
							<TableHead>
								<TableRow>
									<TableCell width={50} />
									<TableCell>Week</TableCell>
									<TableCell align="center">Classes</TableCell>
									<TableCell align="right">Revenue</TableCell>
								</TableRow>
							</TableHead>
							<TableBody>
								{weeklyData.map((week) => (
									<WeekRow
										key={week.week_start}
										week={week}
										navigate={navigate}
									/>
								))}
							</TableBody>
						</Table>
					</TableContainer>
				)}
			</Paper>
		</Box>
	);
}
