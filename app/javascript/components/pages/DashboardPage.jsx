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
	Chip,
	Grid,
	Alert,
} from "@mui/material";
import KeyboardArrowDownIcon from "@mui/icons-material/KeyboardArrowDown";
import KeyboardArrowUpIcon from "@mui/icons-material/KeyboardArrowUp";
import { reportsApi } from "../../utils/api";
import EarthkinLoader from "../shared/EarthkinLoader";

const money = (v) => `$${Number(v || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

// Parse date-only strings ("2026-08-24") in local time; new Date(str) reads
// them as UTC and shifts the day in western timezones.
const parseDateOnly = (dateStr) => {
	const [y, m, d] = String(dateStr).split("T")[0].split("-");
	return new Date(y, m - 1, d);
};

const formatDate = (dateStr) =>
	dateStr ? parseDateOnly(dateStr).toLocaleDateString("en-US", { month: "short", day: "numeric" }) : "";

const STATUS_CHIPS = {
	paid: { label: "Paid", color: "success" },
	due: { label: "Due", color: "default" },
	overdue: { label: "Overdue", color: "error" },
};

function WeekRow({ week, navigate }) {
	const [open, setOpen] = useState(false);
	const isPast = !week.current && parseDateOnly(week.week_end) < new Date();
	const hasLines = week.lines.length > 0;

	return (
		<>
			<TableRow
				sx={{
					"& > *": { borderBottom: "unset" },
					backgroundColor: week.current ? "action.selected" : "inherit",
				}}
			>
				<TableCell>
					{hasLines && (
						<IconButton size="small" onClick={() => setOpen(!open)} aria-label={open ? "Hide details" : "Show details"}>
							{open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />}
						</IconButton>
					)}
				</TableCell>
				<TableCell>
					<Typography fontWeight={week.current ? "bold" : "normal"}>
						{formatDate(week.week_start)} - {formatDate(week.week_end)}
						{week.current && " (This Week)"}
					</Typography>
				</TableCell>
				<TableCell align="right">
					<Typography color={week.collected > 0 ? "success.main" : "text.secondary"}>
						{money(week.collected)}
					</Typography>
				</TableCell>
				<TableCell align="right">
					<Typography
						fontWeight="medium"
						color={week.outstanding > 0 ? (isPast ? "error.main" : "text.primary") : "text.secondary"}
					>
						{money(week.outstanding)}
					</Typography>
				</TableCell>
			</TableRow>
			<TableRow>
				<TableCell style={{ paddingBottom: 0, paddingTop: 0 }} colSpan={4}>
					<Collapse in={open} timeout="auto" unmountOnExit>
						<Box sx={{ margin: 2 }}>
							<Table size="small">
								<TableHead>
									<TableRow>
										<TableCell>Date</TableCell>
										<TableCell>Child</TableCell>
										<TableCell>Program</TableCell>
										<TableCell>For</TableCell>
										<TableCell align="right">Amount</TableCell>
										<TableCell>Status</TableCell>
									</TableRow>
								</TableHead>
								<TableBody>
									{week.lines.map((line, i) => {
										const chip = STATUS_CHIPS[line.status] || STATUS_CHIPS.due;
										return (
											<TableRow
												key={`${line.enrollment_id}-${line.date}-${i}`}
												hover
												sx={{ cursor: "pointer" }}
												onClick={() => navigate(`/enrollments/${line.enrollment_id}`)}
											>
												<TableCell>{formatDate(line.date)}</TableCell>
												<TableCell>{line.child_name || "—"}</TableCell>
												<TableCell>{line.program_name || "—"}</TableCell>
												<TableCell>{line.label}</TableCell>
												<TableCell align="right">{money(line.amount)}</TableCell>
												<TableCell>
													<Chip size="small" label={chip.label} color={chip.color} />
												</TableCell>
											</TableRow>
										);
									})}
								</TableBody>
							</Table>
						</Box>
					</Collapse>
				</TableCell>
			</TableRow>
		</>
	);
}

function Stat({ label, value, color, caption }) {
	return (
		<Box>
			<Typography variant="body2" color="text.secondary">
				{label}
			</Typography>
			<Typography variant="h6" color={color}>
				{value}
			</Typography>
			{caption && (
				<Typography variant="caption" color="text.secondary">
					{caption}
				</Typography>
			)}
		</Box>
	);
}

export default function DashboardPage() {
	const navigate = useNavigate();
	const [forecast, setForecast] = useState(null);
	const [error, setError] = useState(null);
	const [loading, setLoading] = useState(true);

	useEffect(() => {
		reportsApi
			.weeklyRevenue()
			.then(setForecast)
			.catch((err) => setError(err.message))
			.finally(() => setLoading(false));
	}, []);

	if (loading) {
		return (
			<Box sx={{ display: "flex", justifyContent: "center", p: 4 }}>
				<EarthkinLoader />
			</Box>
		);
	}

	const totals = forecast?.totals;
	const weeks = forecast?.weeks || [];
	const hasActivity = weeks.some((w) => w.lines.length > 0);

	return (
		<Box>
			<Typography variant="h4" gutterBottom>
				Dashboard
			</Typography>

			<Paper sx={{ p: 3, mb: 3 }}>
				<Typography variant="h6" gutterBottom>
					Weekly Revenue Forecast
				</Typography>
				<Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
					Payments collected, and tuition installments and invoices coming due, by week.
				</Typography>

				{error && <Alert severity="error">{error}</Alert>}

				{totals && (
					<Grid container spacing={3} sx={{ mb: 2 }}>
						<Grid size={{ xs: 12, sm: 4 }}>
							<Stat label="Expected, next 12 weeks" value={money(totals.expected_upcoming)} />
						</Grid>
						<Grid size={{ xs: 12, sm: 4 }}>
							<Stat
								label="Collected"
								value={money(totals.collected_recent)}
								color="success.main"
								caption={`Since ${formatDate(totals.collected_since)}`}
							/>
						</Grid>
						<Grid size={{ xs: 12, sm: 4 }}>
							<Stat
								label="Overdue"
								value={money(totals.overdue)}
								color={totals.overdue > 0 ? "error.main" : undefined}
								caption="Unpaid and due before this week"
							/>
						</Grid>
					</Grid>
				)}

				{forecast && !hasActivity ? (
					<Typography color="text.secondary">No payments collected or coming due in this period.</Typography>
				) : (
					forecast && (
						<TableContainer>
							<Table>
								<TableHead>
									<TableRow>
										<TableCell width={50} />
										<TableCell>Week</TableCell>
										<TableCell align="right">Collected</TableCell>
										<TableCell align="right">Outstanding</TableCell>
									</TableRow>
								</TableHead>
								<TableBody>
									{weeks.map((week) => (
										<WeekRow key={week.week_start} week={week} navigate={navigate} />
									))}
								</TableBody>
							</Table>
						</TableContainer>
					)
				)}
			</Paper>
		</Box>
	);
}
