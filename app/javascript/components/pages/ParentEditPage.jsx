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
import { parentsApi } from "../../utils/api";
import EarthkinLoader from "../shared/EarthkinLoader";

export default function ParentEditPage() {
	const { id } = useParams();
	const navigate = useNavigate();
	const [parent, setParent] = useState(null);
	const [loading, setLoading] = useState(true);
	const [saving, setSaving] = useState(false);
	const [error, setError] = useState(null);
	const [formData, setFormData] = useState({
		first_name: "",
		last_name: "",
		email: "",
		phone: "",
	});

	useEffect(() => {
		const loadParent = async () => {
			setLoading(true);
			try {
				const data = await parentsApi.get(id);
				setParent(data);
				setFormData({
					first_name: data.first_name || "",
					last_name: data.last_name || "",
					email: data.email || "",
					phone: data.phone || "",
				});
			} finally {
				setLoading(false);
			}
		};
		loadParent();
	}, [id]);

	const handleChange = (field, value) => {
		setFormData((prev) => ({ ...prev, [field]: value }));
	};

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setSaving(true);
		try {
			await parentsApi.update(id, formData);
			navigate(`/families/${parent.family_id}`);
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

	if (!parent) {
		return <Typography>Parent not found</Typography>;
	}

	return (
		<Box>
			<Button
				startIcon={<ArrowBackIcon />}
				onClick={() => navigate(`/families/${parent.family_id}`)}
				sx={{ mb: 2 }}
			>
				Back to Family
			</Button>

			<Typography variant="h4" gutterBottom>
				Edit Parent
			</Typography>

			<Paper sx={{ p: 3, maxWidth: 600 }}>
				{error && (
					<Alert severity="error" sx={{ mb: 2 }}>
						{error}
					</Alert>
				)}

				<Box component="form" onSubmit={handleSubmit} sx={{ display: "flex", flexDirection: "column", gap: 2 }}>
					<TextField
						label="First Name"
						value={formData.first_name}
						onChange={(e) => handleChange("first_name", e.target.value)}
						required
						fullWidth
					/>
					<TextField
						label="Last Name"
						value={formData.last_name}
						onChange={(e) => handleChange("last_name", e.target.value)}
						required
						fullWidth
					/>
					<TextField
						label="Email"
						type="email"
						value={formData.email}
						onChange={(e) => handleChange("email", e.target.value)}
						required
						fullWidth
					/>
					<TextField
						label="Phone"
						value={formData.phone}
						onChange={(e) => handleChange("phone", e.target.value)}
						fullWidth
					/>
					<Box sx={{ display: "flex", gap: 2, mt: 2 }}>
						<Button variant="outlined" onClick={() => navigate(`/families/${parent.family_id}`)}>
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
