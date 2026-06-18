import { useState, useEffect, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
	Box,
	Typography,
	Button,
	Paper,
	Avatar,
	TextField,
	Grid,
	Chip,
	IconButton,
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import EditIcon from "@mui/icons-material/Edit";
import PhotoCameraIcon from "@mui/icons-material/PhotoCamera";
import { teachersApi } from "../../utils/api";

export default function TeacherDetailPage() {
	const { id } = useParams();
	const navigate = useNavigate();
	const fileInputRef = useRef(null);
	const [teacher, setTeacher] = useState(null);
	const [loading, setLoading] = useState(true);
	const [editing, setEditing] = useState(false);
	const [formData, setFormData] = useState({});
	const [saving, setSaving] = useState(false);

	const loadTeacher = async () => {
		setLoading(true);
		try {
			const data = await teachersApi.get(id);
			setTeacher(data);
			setFormData({
				first_name: data.first_name || "",
				last_name: data.last_name || "",
				email: data.email || "",
				phone: data.phone || "",
				bio: data.bio || "",
			});
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		loadTeacher();
	}, [id]);

	const handleSave = async () => {
		setSaving(true);
		try {
			await teachersApi.update(id, formData);
			setEditing(false);
			loadTeacher();
		} finally {
			setSaving(false);
		}
	};

	const handleAvatarClick = () => {
		fileInputRef.current?.click();
	};

	const handleAvatarChange = async (event) => {
		const file = event.target.files?.[0];
		if (!file) return;

		// Convert to base64
		const reader = new FileReader();
		reader.onload = async (e) => {
			const base64 = e.target?.result;
			if (base64) {
				setSaving(true);
				try {
					await teachersApi.update(id, { avatar: base64 });
					loadTeacher();
				} finally {
					setSaving(false);
				}
			}
		};
		reader.readAsDataURL(file);
	};

	const handleChange = (field) => (event) => {
		setFormData((prev) => ({ ...prev, [field]: event.target.value }));
	};

	if (loading) {
		return <Typography>Loading...</Typography>;
	}

	if (!teacher) {
		return <Typography>Teacher not found</Typography>;
	}

	return (
		<Box>
			<Button
				startIcon={<ArrowBackIcon />}
				onClick={() => navigate("/teachers")}
				sx={{ mb: 2 }}
			>
				Back to Teachers
			</Button>

			<Paper sx={{ p: 3, mb: 3 }}>
				<Box sx={{ display: "flex", gap: 3, alignItems: "flex-start" }}>
					<Box sx={{ position: "relative" }}>
						<Avatar
							src={teacher.avatar_url}
							alt={teacher.full_name}
							sx={{ width: 120, height: 120, fontSize: "2.5rem" }}
						>
							{teacher.first_name?.[0]}{teacher.last_name?.[0]}
						</Avatar>
						<IconButton
							sx={{
								position: "absolute",
								bottom: 0,
								right: 0,
								backgroundColor: "background.paper",
								"&:hover": { backgroundColor: "action.hover" },
							}}
							size="small"
							onClick={handleAvatarClick}
							disabled={saving}
						>
							<PhotoCameraIcon fontSize="small" />
						</IconButton>
						<input
							type="file"
							ref={fileInputRef}
							onChange={handleAvatarChange}
							accept="image/*"
							style={{ display: "none" }}
						/>
					</Box>

					<Box sx={{ flex: 1 }}>
						{editing ? (
							<Grid container spacing={2}>
								<Grid size={{ xs: 12, sm: 6 }}>
									<TextField
										fullWidth
										label="First Name"
										value={formData.first_name}
										onChange={handleChange("first_name")}
										required
									/>
								</Grid>
								<Grid size={{ xs: 12, sm: 6 }}>
									<TextField
										fullWidth
										label="Last Name"
										value={formData.last_name}
										onChange={handleChange("last_name")}
										required
									/>
								</Grid>
								<Grid size={{ xs: 12, sm: 6 }}>
									<TextField
										fullWidth
										label="Email"
										type="email"
										value={formData.email}
										onChange={handleChange("email")}
										required
									/>
								</Grid>
								<Grid size={{ xs: 12, sm: 6 }}>
									<TextField
										fullWidth
										label="Phone"
										value={formData.phone}
										onChange={handleChange("phone")}
									/>
								</Grid>
								<Grid size={{ xs: 12 }}>
									<TextField
										fullWidth
										label="Bio"
										multiline
										rows={3}
										value={formData.bio}
										onChange={handleChange("bio")}
									/>
								</Grid>
								<Grid size={{ xs: 12 }}>
									<Box sx={{ display: "flex", gap: 1 }}>
										<Button
											variant="contained"
											onClick={handleSave}
											disabled={saving}
										>
											{saving ? "Saving..." : "Save"}
										</Button>
										<Button onClick={() => setEditing(false)}>Cancel</Button>
									</Box>
								</Grid>
							</Grid>
						) : (
							<>
								<Box sx={{ display: "flex", alignItems: "center", gap: 1, mb: 1 }}>
									<Typography variant="h4">
										{teacher.full_name}
									</Typography>
									<IconButton size="small" onClick={() => setEditing(true)}>
										<EditIcon fontSize="small" />
									</IconButton>
								</Box>
								<Typography color="text.secondary" gutterBottom>
									{teacher.email}
								</Typography>
								{teacher.phone && (
									<Typography color="text.secondary" gutterBottom>
										{teacher.phone}
									</Typography>
								)}
								{teacher.bio && (
									<Typography sx={{ mt: 2 }}>{teacher.bio}</Typography>
								)}
							</>
						)}
					</Box>
				</Box>
			</Paper>

			{teacher.programs?.length > 0 && (
				<Paper sx={{ p: 3, mb: 3 }}>
					<Typography variant="h6" gutterBottom>
						Assigned Programs
					</Typography>
					<Box sx={{ display: "flex", gap: 1, flexWrap: "wrap" }}>
						{teacher.programs.map((program) => (
							<Chip
								key={program.id}
								label={program.name}
								onClick={() => navigate(`/programs/${program.id}`)}
								clickable
							/>
						))}
					</Box>
				</Paper>
			)}

			{teacher.program_classes?.length > 0 && (
				<Paper sx={{ p: 3 }}>
					<Typography variant="h6" gutterBottom>
						Assigned Classes
					</Typography>
					<Box sx={{ display: "flex", gap: 1, flexWrap: "wrap" }}>
						{teacher.program_classes.map((pc) => (
							<Chip
								key={pc.id}
								label={`${pc.name} (${new Date(pc.date).toLocaleDateString()})`}
							/>
						))}
					</Box>
				</Paper>
			)}
		</Box>
	);
}
