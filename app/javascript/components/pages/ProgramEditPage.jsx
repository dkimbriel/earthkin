import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
	Box,
	Typography,
	Button,
	Paper,
	TextField,
	Alert,
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import { programsApi } from "../../utils/api";
import EarthkinLoader from "../shared/EarthkinLoader";

export default function ProgramEditPage() {
	const { id } = useParams();
	const navigate = useNavigate();
	const [program, setProgram] = useState(null);
	const [loading, setLoading] = useState(true);
	const [saving, setSaving] = useState(false);
	const [error, setError] = useState(null);
	const [formData, setFormData] = useState({
		name: "",
		description: "",
		start_date: "",
		end_date: "",
		capacity: "",
		enrollment_fee: "",
		class_days: "",
		start_time: "",
		end_time: "",
	});

	useEffect(() => {
		const loadProgram = async () => {
			setLoading(true);
			try {
				const data = await programsApi.get(id);
				setProgram(data);
				setFormData({
					name: data.name || "",
					description: data.description || "",
					start_date: data.start_date || "",
					end_date: data.end_date || "",
					capacity: data.capacity || "",
					enrollment_fee: data.enrollment_fee || "",
					class_days: data.class_days || "",
					start_time: data.start_time ? data.start_time.substring(11, 16) : "",
					end_time: data.end_time ? data.end_time.substring(11, 16) : "",
				});
			} finally {
				setLoading(false);
			}
		};
		loadProgram();
	}, [id]);

	const handleChange = (field, value) => {
		setFormData((prev) => ({ ...prev, [field]: value }));
	};

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setSaving(true);
		try {
			await programsApi.update(id, {
				...formData,
				capacity: formData.capacity ? parseInt(formData.capacity, 10) : null,
				enrollment_fee: formData.enrollment_fee ? parseFloat(formData.enrollment_fee) : null,
			});
			navigate(`/programs/${id}`);
		} catch (err) {
			setError(err.message);
		} finally {
			setSaving(false);
		}
	};

	if (loading) {
		return (
			<Box sx={{ display: "flex", justifyContent: "center", p: 4 }}>
				<EarthkinLoader />
			</Box>
		);
	}

	if (!program) {
		return <Typography>Program not found</Typography>;
	}

	return (
		<Box>
			<Button
				startIcon={<ArrowBackIcon />}
				onClick={() => navigate(`/programs/${id}`)}
				sx={{ mb: 2 }}
			>
				Back to Program
			</Button>

			<Typography variant="h4" gutterBottom>
				Edit Program
			</Typography>

			<Paper sx={{ p: 3, maxWidth: 600 }}>
				{error && (
					<Alert severity="error" sx={{ mb: 2 }}>
						{error}
					</Alert>
				)}

				<Box component="form" onSubmit={handleSubmit} sx={{ display: "flex", flexDirection: "column", gap: 2 }}>
					<TextField
						label="Program Name"
						value={formData.name}
						onChange={(e) => handleChange("name", e.target.value)}
						required
						fullWidth
					/>
					<TextField
						label="Description"
						value={formData.description}
						onChange={(e) => handleChange("description", e.target.value)}
						fullWidth
						multiline
						rows={3}
					/>
					<TextField
						label="Start Date"
						type="date"
						value={formData.start_date}
						onChange={(e) => handleChange("start_date", e.target.value)}
						fullWidth
						slotProps={{ inputLabel: { shrink: true } }}
					/>
					<TextField
						label="End Date"
						type="date"
						value={formData.end_date}
						onChange={(e) => handleChange("end_date", e.target.value)}
						fullWidth
						slotProps={{ inputLabel: { shrink: true } }}
					/>
					<TextField
						label="Capacity"
						type="number"
						value={formData.capacity}
						onChange={(e) => handleChange("capacity", e.target.value)}
						fullWidth
						helperText="Maximum number of children that can enroll"
					/>

					<Typography variant="subtitle1" sx={{ mt: 2, fontWeight: 'bold' }}>
						Schedule & Fees
					</Typography>

					<TextField
						label="Class Days"
						value={formData.class_days}
						onChange={(e) => handleChange("class_days", e.target.value)}
						fullWidth
						placeholder="e.g., Monday & Wednesday"
						helperText="Days of the week when classes are held"
					/>
					<Box sx={{ display: "flex", gap: 2 }}>
						<TextField
							label="Start Time"
							type="time"
							value={formData.start_time}
							onChange={(e) => handleChange("start_time", e.target.value)}
							fullWidth
							slotProps={{ inputLabel: { shrink: true } }}
						/>
						<TextField
							label="End Time"
							type="time"
							value={formData.end_time}
							onChange={(e) => handleChange("end_time", e.target.value)}
							fullWidth
							slotProps={{ inputLabel: { shrink: true } }}
						/>
					</Box>
					<TextField
						label="Enrollment Fee"
						type="number"
						value={formData.enrollment_fee}
						onChange={(e) => handleChange("enrollment_fee", e.target.value)}
						fullWidth
						slotProps={{
							input: { startAdornment: <Typography sx={{ mr: 0.5 }}>$</Typography> }
						}}
						helperText="Non-refundable fee to secure enrollment"
					/>
					<Box sx={{ display: "flex", gap: 2, mt: 2 }}>
						<Button variant="outlined" onClick={() => navigate(`/programs/${id}`)}>
							Cancel
						</Button>
						<Button type="submit" variant="contained" disabled={saving}>
							{saving ? "Saving..." : "Save Changes"}
						</Button>
					</Box>
				</Box>
			</Paper>
		</Box>
	);
}
