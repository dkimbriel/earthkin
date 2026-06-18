import {
	Dialog,
	DialogTitle,
	DialogContent,
	DialogActions,
	Button,
	TextField,
	MenuItem,
	Box,
	Alert,
} from "@mui/material";
import { useState } from "react";

export default function FormDialog({
	open,
	onClose,
	onSubmit,
	title,
	fields,
	submitLabel = "Create",
}) {
	const [formData, setFormData] = useState(() =>
		fields.reduce((acc, field) => {
			acc[field.name] = field.defaultValue ?? "";
			return acc;
		}, {})
	);
	const [error, setError] = useState(null);
	const [submitting, setSubmitting] = useState(false);

	const handleChange = (name, value) => {
		setFormData((prev) => ({ ...prev, [name]: value }));
	};

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setSubmitting(true);
		try {
			await onSubmit(formData);
			setFormData(
				fields.reduce((acc, field) => {
					acc[field.name] = field.defaultValue ?? "";
					return acc;
				}, {})
			);
			onClose();
		} catch (err) {
			setError(err.message);
		} finally {
			setSubmitting(false);
		}
	};

	const handleClose = () => {
		setError(null);
		setFormData(
			fields.reduce((acc, field) => {
				acc[field.name] = field.defaultValue ?? "";
				return acc;
			}, {})
		);
		onClose();
	};

	return (
		<Dialog open={open} onClose={handleClose} maxWidth="sm" fullWidth>
			<form onSubmit={handleSubmit}>
				<DialogTitle>{title}</DialogTitle>
				<DialogContent>
					{error && (
						<Alert severity="error" sx={{ mb: 2 }}>
							{error}
						</Alert>
					)}
					<Box sx={{ display: "flex", flexDirection: "column", gap: 2, mt: 1 }}>
						{fields.map((field) => {
							if (field.type === "select") {
								return (
									<TextField
										key={field.name}
										select
										label={field.label}
										value={formData[field.name]}
										onChange={(e) => handleChange(field.name, e.target.value)}
										required={field.required}
										fullWidth
									>
										{field.options?.map((option) => (
											<MenuItem key={option.value} value={option.value}>
												{option.label}
											</MenuItem>
										))}
									</TextField>
								);
							}
							return (
								<TextField
									key={field.name}
									label={field.label}
									type={field.type || "text"}
									value={formData[field.name]}
									onChange={(e) => handleChange(field.name, e.target.value)}
									required={field.required}
									fullWidth
									multiline={field.multiline}
									rows={field.rows}
									slotProps={["date", "time"].includes(field.type) ? { inputLabel: { shrink: true } } : undefined}
								/>
							);
						})}
					</Box>
				</DialogContent>
				<DialogActions>
					<Button onClick={handleClose}>Cancel</Button>
					<Button type="submit" variant="contained" disabled={submitting}>
						{submitting ? "Saving..." : submitLabel}
					</Button>
				</DialogActions>
			</form>
		</Dialog>
	);
}
