import { useState, useEffect } from "react";
import { useParams, useNavigate, useLocation } from "react-router-dom";
import {
	Box,
	Typography,
	Button,
	Paper,
	TextField,
	Alert,
	MenuItem,
	List,
	ListItem,
	ListItemText,
	ListItemAvatar,
	Divider,
	Avatar,
	Chip,
	IconButton,
	Autocomplete,
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import AddIcon from "@mui/icons-material/Add";
import { programClassesApi, locationsApi, programEnrollmentsApi, teachersApi } from "../../utils/api";
import EarthkinLoader from "../shared/EarthkinLoader";

export default function ProgramClassEditPage() {
	const { id } = useParams();
	const navigate = useNavigate();
	const location = useLocation();
	const [programClass, setProgramClass] = useState(null);
	const [locations, setLocations] = useState([]);
	const [enrollments, setEnrollments] = useState([]);
	const [allTeachers, setAllTeachers] = useState([]);
	const [loading, setLoading] = useState(true);
	const [saving, setSaving] = useState(false);
	const [error, setError] = useState(null);
	const [showTeacherSelect, setShowTeacherSelect] = useState(false);
	const [selectedTeacher, setSelectedTeacher] = useState(null);
	const [formData, setFormData] = useState({
		name: "",
		date: "",
		start_time: "",
		end_time: "",
		location_id: "",
	});

	const backPath = location.state?.from || null;

	const loadData = async () => {
		setLoading(true);
		try {
			const [classData, locationsData, teachersData] = await Promise.all([
				programClassesApi.get(id),
				locationsApi.list(),
				teachersApi.list(),
			]);
			setProgramClass(classData);
			setLocations(locationsData);
			setAllTeachers(teachersData);
			setFormData({
				name: classData.name || "",
				date: classData.date || "",
				start_time: extractTime(classData.start_time),
				end_time: extractTime(classData.end_time),
				location_id: classData.location_id || "",
			});
			// Fetch enrollments for this program
			if (classData.program?.id) {
				const enrollmentsData = await programEnrollmentsApi.list({ programId: classData.program.id });
				// Only show confirmed enrollments
				setEnrollments(enrollmentsData.filter(e => e.status === "confirmed"));
			}
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		loadData();
	}, [id]);

	const extractTime = (timeStr) => {
		if (!timeStr) return "";
		// Extract HH:MM from Rails datetime format "2000-01-01T08:00:00.000Z"
		const match = timeStr.match(/T(\d{2}:\d{2})/);
		return match ? match[1] : "";
	};

	const handleChange = (field, value) => {
		setFormData((prev) => ({ ...prev, [field]: value }));
	};

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setSaving(true);
		try {
			await programClassesApi.update(id, formData);
			navigate(`/programs/${programClass.program?.id}`);
		} catch (err) {
			setError(err.message);
		} finally {
			setSaving(false);
		}
	};

	const handleAssignTeacher = async () => {
		if (!selectedTeacher) return;
		await programClassesApi.assignTeacher(id, selectedTeacher.id);
		setSelectedTeacher(null);
		setShowTeacherSelect(false);
		loadData();
	};

	const handleUnassignTeacher = async (teacherId) => {
		await programClassesApi.unassignTeacher(id, teacherId);
		loadData();
	};

	if (loading) {
		return (
			<Box sx={{ display: "flex", justifyContent: "center", p: 4 }}>
				<EarthkinLoader />
			</Box>
		);
	}

	if (!programClass) {
		return <Typography>Class not found</Typography>;
	}

	const handleBack = () => {
		if (backPath) {
			navigate(backPath);
		} else {
			navigate(`/programs/${programClass.program?.id}`);
		}
	};

	// Check if class is in the past
	const isClassInPast = () => {
		if (!programClass.date) return false;
		const [year, month, day] = programClass.date.split("-");
		const classDate = new Date(year, month - 1, day);
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		return classDate < today;
	};

	const isPast = isClassInPast();
	const assignedTeacherIds = programClass.teachers?.map(t => t.id) || [];
	const availableTeachers = allTeachers.filter(t => !assignedTeacherIds.includes(t.id));

	return (
		<Box>
			<Button
				startIcon={<ArrowBackIcon />}
				onClick={handleBack}
				sx={{ mb: 2 }}
			>
				{backPath === "/calendar" ? "Back to Calendar" : "Back to Program"}
			</Button>

			<Typography variant="h4" gutterBottom>
				{isPast ? "View Class" : "Edit Class"}
			</Typography>
			{programClass.program?.name && (
				<Typography
					variant="subtitle1"
					color="text.secondary"
					sx={{ mb: 2, cursor: "pointer", "&:hover": { textDecoration: "underline" } }}
					onClick={() => navigate(`/programs/${programClass.program.id}`)}
				>
					{programClass.program.name}
				</Typography>
			)}

			{isPast && (
				<Alert severity="info" sx={{ mb: 2 }}>
					This class has already occurred and cannot be edited.
				</Alert>
			)}

			<Box sx={{ display: "flex", gap: 3, flexWrap: "wrap", alignItems: "flex-start" }}>
				<Paper sx={{ p: 3, flex: "1 1 400px", maxWidth: 600 }}>
					{error && (
						<Alert severity="error" sx={{ mb: 2 }}>
							{error}
						</Alert>
					)}

					<Box component="form" onSubmit={handleSubmit} sx={{ display: "flex", flexDirection: "column", gap: 2 }}>
						<TextField
							label="Class Name"
							value={formData.name}
							onChange={(e) => handleChange("name", e.target.value)}
							required
							fullWidth
							disabled={isPast}
						/>
						<TextField
							label="Date"
							type="date"
							value={formData.date}
							onChange={(e) => handleChange("date", e.target.value)}
							required
							fullWidth
							slotProps={{ inputLabel: { shrink: true } }}
							disabled={isPast}
						/>
						<TextField
							label="Start Time"
							type="time"
							value={formData.start_time}
							onChange={(e) => handleChange("start_time", e.target.value)}
							fullWidth
							slotProps={{ inputLabel: { shrink: true } }}
							disabled={isPast}
						/>
						<TextField
							label="End Time"
							type="time"
							value={formData.end_time}
							onChange={(e) => handleChange("end_time", e.target.value)}
							fullWidth
							slotProps={{ inputLabel: { shrink: true } }}
							disabled={isPast}
						/>
						<TextField
							select
							label="Location"
							value={formData.location_id}
							onChange={(e) => handleChange("location_id", e.target.value)}
							fullWidth
							disabled={isPast}
						>
							<MenuItem value="">
								<em>None</em>
							</MenuItem>
							{locations.map((loc) => (
								<MenuItem key={loc.id} value={loc.id}>
									{loc.name}
								</MenuItem>
							))}
						</TextField>
						{!isPast && (
							<Box sx={{ display: "flex", gap: 2, mt: 2 }}>
								<Button
									variant="outlined"
									onClick={handleBack}
								>
									Cancel
								</Button>
								<Button type="submit" variant="contained" disabled={saving}>
									{saving ? "Saving..." : "Save Changes"}
								</Button>
							</Box>
						)}
					</Box>
				</Paper>

				<Box sx={{ display: "flex", flexDirection: "column", gap: 3, flex: "1 1 300px", maxWidth: 400 }}>
					<Paper sx={{ p: 3 }}>
						<Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 1 }}>
							<Typography variant="h6">
								Teachers ({programClass.teachers?.length || 0})
							</Typography>
							{!isPast && availableTeachers.length > 0 && !showTeacherSelect && (
								<IconButton size="small" onClick={() => setShowTeacherSelect(true)}>
									<AddIcon />
								</IconButton>
							)}
						</Box>
						{!isPast && showTeacherSelect && (
							<Box sx={{ mb: 2 }}>
								<Autocomplete
									size="small"
									options={availableTeachers}
									getOptionLabel={(option) => `${option.first_name} ${option.last_name}`}
									value={selectedTeacher}
									onChange={(_, newValue) => setSelectedTeacher(newValue)}
									renderOption={(props, option) => {
										const { key, ...otherProps } = props;
										return (
											<Box component="li" key={key} {...otherProps} sx={{ display: "flex", alignItems: "center", gap: 1 }}>
												<Avatar src={option.avatar_url} sx={{ width: 24, height: 24 }}>
													{option.first_name?.[0]}{option.last_name?.[0]}
												</Avatar>
												{option.first_name} {option.last_name}
											</Box>
										);
									}}
									renderInput={(params) => <TextField {...params} label="Select Teacher" />}
								/>
								<Box sx={{ display: "flex", gap: 1, mt: 1 }}>
									<Button size="small" onClick={() => { setShowTeacherSelect(false); setSelectedTeacher(null); }}>
										Cancel
									</Button>
									<Button size="small" variant="contained" onClick={handleAssignTeacher} disabled={!selectedTeacher}>
										Add
									</Button>
								</Box>
							</Box>
						)}
						{programClass.teachers?.length > 0 ? (
							<Box sx={{ display: "flex", gap: 1, flexWrap: "wrap" }}>
								{programClass.teachers.map((teacher) => (
									<Chip
										key={teacher.id}
										avatar={
											<Avatar src={teacher.avatar_url}>
												{teacher.first_name?.[0]}{teacher.last_name?.[0]}
											</Avatar>
										}
										label={`${teacher.first_name} ${teacher.last_name}`}
										onDelete={isPast ? undefined : () => handleUnassignTeacher(teacher.id)}
										onClick={() => navigate(`/teachers/${teacher.id}`)}
										clickable
										size="small"
									/>
								))}
							</Box>
						) : (
							!showTeacherSelect && (
								<Typography color="text.secondary">
									No teachers assigned to this class.
								</Typography>
							)
						)}
					</Paper>

					<Paper sx={{ p: 3 }}>
						<Typography variant="h6" gutterBottom>
							Children ({enrollments.length})
						</Typography>
						{enrollments.length > 0 ? (
							<List dense disablePadding>
								{enrollments.map((enrollment, index) => (
									<Box key={enrollment.id}>
										{index > 0 && <Divider />}
										<ListItem
											sx={{ cursor: "pointer", px: 0 }}
											onClick={() => navigate(`/children/${enrollment.child?.id}`)}
										>
											<ListItemText
												primary={`${enrollment.child?.first_name} ${enrollment.child?.last_name}`}
												secondary={enrollment.child?.family?.name}
											/>
										</ListItem>
									</Box>
								))}
							</List>
						) : (
							<Typography color="text.secondary">
								No confirmed children for this class.
							</Typography>
						)}
					</Paper>
				</Box>
			</Box>
		</Box>
	);
}
