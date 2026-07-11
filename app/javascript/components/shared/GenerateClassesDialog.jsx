import { useState } from "react";
import {
	Dialog,
	DialogTitle,
	DialogContent,
	DialogActions,
	Button,
	TextField,
	Box,
	Alert,
	FormGroup,
	FormControlLabel,
	Checkbox,
	Typography,
} from "@mui/material";
import { programsApi } from "../../utils/api";

const DAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);

export default function GenerateClassesDialog({ open, onClose, program, onGenerated }) {
	const defaultDays = DAYS.filter((d) => (program.class_days || "").toLowerCase().includes(d));
	const [days, setDays] = useState(defaultDays);
	const [startDate, setStartDate] = useState(program.start_date || "");
	const [endDate, setEndDate] = useState(program.end_date || "");
	const [skipDates, setSkipDates] = useState("");
	const [error, setError] = useState(null);
	const [submitting, setSubmitting] = useState(false);

	const toggleDay = (day) =>
		setDays((prev) => (prev.includes(day) ? prev.filter((d) => d !== day) : [...prev, day]));

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setSubmitting(true);
		try {
			const result = await programsApi.generateClasses(program.id, {
				days_of_week: days,
				start_date: startDate,
				end_date: endDate,
				skip_dates: skipDates,
			});
			onGenerated(result);
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
				<DialogTitle>Generate Classes from Pattern</DialogTitle>
				<DialogContent>
					{error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
					<Box sx={{ display: "flex", flexDirection: "column", gap: 2, mt: 1 }}>
						<Box>
							<Typography variant="subtitle2">Class days</Typography>
							<FormGroup row>
								{DAYS.map((day) => (
									<FormControlLabel
										key={day}
										control={<Checkbox checked={days.includes(day)} onChange={() => toggleDay(day)} />}
										label={cap(day)}
									/>
								))}
							</FormGroup>
						</Box>
						<Box sx={{ display: "flex", gap: 2 }}>
							<TextField
								label="From"
								type="date"
								value={startDate}
								onChange={(e) => setStartDate(e.target.value)}
								required
								fullWidth
								slotProps={{ inputLabel: { shrink: true } }}
							/>
							<TextField
								label="Through"
								type="date"
								value={endDate}
								onChange={(e) => setEndDate(e.target.value)}
								required
								fullWidth
								slotProps={{ inputLabel: { shrink: true } }}
							/>
						</Box>
						<TextField
							label="Skip dates (holidays)"
							value={skipDates}
							onChange={(e) => setSkipDates(e.target.value)}
							fullWidth
							placeholder="2026-11-26, 2026-11-27"
							helperText="Comma-separated dates to skip. Dates that already have a class are always skipped."
						/>
						<Typography variant="body2" color="text.secondary">
							Class times default to the program schedule
							{program.start_time ? ` (${program.start_time.slice(11, 16) || program.start_time})` : ""}.
						</Typography>
					</Box>
				</DialogContent>
				<DialogActions>
					<Button onClick={onClose}>Cancel</Button>
					<Button type="submit" variant="contained" disabled={submitting || days.length === 0}>
						{submitting ? "Generating..." : "Generate"}
					</Button>
				</DialogActions>
			</form>
		</Dialog>
	);
}
