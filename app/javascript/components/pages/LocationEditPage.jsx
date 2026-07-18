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
import { locationsApi } from "../../utils/api";
import EarthkinLoader from "../shared/EarthkinLoader";

export default function LocationEditPage() {
	const { id } = useParams();
	const navigate = useNavigate();
	const [location, setLocation] = useState(null);
	const [loading, setLoading] = useState(true);
	const [saving, setSaving] = useState(false);
	const [error, setError] = useState(null);
	const [formData, setFormData] = useState({
		name: "",
		address: "",
		notes: "",
	});

	useEffect(() => {
		const loadLocation = async () => {
			setLoading(true);
			try {
				const data = await locationsApi.get(id);
				setLocation(data);
				setFormData({
					name: data.name || "",
					address: data.address || "",
					notes: data.notes || "",
				});
			} finally {
				setLoading(false);
			}
		};
		loadLocation();
	}, [id]);

	const handleChange = (field, value) => {
		setFormData((prev) => ({ ...prev, [field]: value }));
	};

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setSaving(true);
		try {
			await locationsApi.update(id, formData);
			navigate("/locations");
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

	if (!location) {
		return <Typography>Location not found</Typography>;
	}

	return (
		<Box>
			<Button
				startIcon={<ArrowBackIcon />}
				onClick={() => navigate("/locations")}
				sx={{ mb: 2 }}
			>
				Back to Locations
			</Button>

			<Typography variant="h4" gutterBottom>
				Edit Location
			</Typography>

			<Paper sx={{ p: 3, maxWidth: 600 }}>
				{error && (
					<Alert severity="error" sx={{ mb: 2 }}>
						{error}
					</Alert>
				)}

				<Box component="form" onSubmit={handleSubmit} sx={{ display: "flex", flexDirection: "column", gap: 2 }}>
					<TextField
						label="Location Name"
						value={formData.name}
						onChange={(e) => handleChange("name", e.target.value)}
						required
						fullWidth
					/>
					<TextField
						label="Address"
						value={formData.address}
						onChange={(e) => handleChange("address", e.target.value)}
						fullWidth
						multiline
						rows={2}
					/>
					<TextField
						label="Notes"
						value={formData.notes}
						onChange={(e) => handleChange("notes", e.target.value)}
						fullWidth
						multiline
						rows={2}
					/>
					<Box sx={{ display: "flex", gap: 2, mt: 2 }}>
						<Button variant="outlined" onClick={() => navigate("/locations")}>
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
