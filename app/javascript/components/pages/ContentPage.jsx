import { useState, useEffect } from "react";
import {
	Box,
	Chip,
	Link,
	Dialog,
	DialogTitle,
	DialogContent,
	DialogActions,
	Button,
	TextField,
	MenuItem,
	Autocomplete,
	FormControlLabel,
	Checkbox,
	Alert,
} from "@mui/material";
import OpenInNewIcon from "@mui/icons-material/OpenInNew";
import DataTable from "../shared/DataTable";
import ConfirmDialog from "../shared/ConfirmDialog";
import PageHeader from "../shared/PageHeader";
import { contentItemsApi, teachersApi } from "../../utils/api";
import { useAuth } from "../../contexts/AuthContext";

const CATEGORY_OPTIONS = ["general", "manual", "curriculum", "form", "policy"];

const EMPTY_FORM = {
	title: "",
	url: "",
	description: "",
	category: "general",
	visibility: "all_staff",
	visible_to_families: false,
	teacher_ids: [],
};

function ContentItemDialog({ open, onClose, onSubmit, initial, teachers, title }) {
	const [form, setForm] = useState(initial || EMPTY_FORM);
	const [error, setError] = useState(null);
	const [submitting, setSubmitting] = useState(false);

	const set = (name, value) => setForm((prev) => ({ ...prev, [name]: value }));

	const handleSubmit = async (e) => {
		e.preventDefault();
		setError(null);
		setSubmitting(true);
		try {
			await onSubmit(form);
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
				<DialogTitle>{title}</DialogTitle>
				<DialogContent>
					{error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
					<Box sx={{ display: "flex", flexDirection: "column", gap: 2, mt: 1 }}>
						<TextField
							label="Title"
							value={form.title}
							onChange={(e) => set("title", e.target.value)}
							required
							fullWidth
						/>
						<TextField
							label="Link (Google Drive URL)"
							value={form.url}
							onChange={(e) => set("url", e.target.value)}
							required
							fullWidth
							placeholder="https://drive.google.com/..."
						/>
						<TextField
							label="Description"
							value={form.description || ""}
							onChange={(e) => set("description", e.target.value)}
							multiline
							rows={2}
							fullWidth
						/>
						<TextField
							select
							label="Category"
							value={form.category}
							onChange={(e) => set("category", e.target.value)}
							fullWidth
						>
							{CATEGORY_OPTIONS.map((c) => (
								<MenuItem key={c} value={c}>
									{c.charAt(0).toUpperCase() + c.slice(1)}
								</MenuItem>
							))}
						</TextField>
						<TextField
							select
							label="Who can see this"
							value={form.visibility}
							onChange={(e) => set("visibility", e.target.value)}
							fullWidth
						>
							<MenuItem value="all_staff">All staff</MenuItem>
							<MenuItem value="specific_teachers">Specific teachers</MenuItem>
						</TextField>
						{form.visibility === "specific_teachers" && (
							<Autocomplete
								multiple
								options={teachers}
								getOptionLabel={(t) => t.full_name}
								value={teachers.filter((t) => form.teacher_ids.includes(t.id))}
								onChange={(_, selected) => set("teacher_ids", selected.map((t) => t.id))}
								renderInput={(params) => (
									<TextField {...params} label="Teachers" placeholder="Select teachers" />
								)}
							/>
						)}
						<FormControlLabel
							control={
								<Checkbox
									checked={form.visible_to_families}
									onChange={(e) => set("visible_to_families", e.target.checked)}
								/>
							}
							label="Also show to families in the parent portal (e.g. Family Handbook, Gear & Attire List)"
						/>
					</Box>
				</DialogContent>
				<DialogActions>
					<Button onClick={onClose}>Cancel</Button>
					<Button type="submit" variant="contained" disabled={submitting}>
						{submitting ? "Saving..." : "Save"}
					</Button>
				</DialogActions>
			</form>
		</Dialog>
	);
}

export default function ContentPage() {
	const { user } = useAuth();
	const isAdmin = user?.role === "admin";
	const [items, setItems] = useState([]);
	const [teachers, setTeachers] = useState([]);
	const [loading, setLoading] = useState(true);
	const [showForm, setShowForm] = useState(false);
	const [editTarget, setEditTarget] = useState(null);
	const [deleteTarget, setDeleteTarget] = useState(null);

	const loadItems = async () => {
		setLoading(true);
		try {
			const data = await contentItemsApi.list();
			setItems(data);
		} finally {
			setLoading(false);
		}
	};

	useEffect(() => {
		loadItems();
		if (isAdmin) {
			teachersApi.list().then(setTeachers).catch(() => {});
		}
	}, [isAdmin]);

	const columns = [
		{
			key: "title",
			label: "Title",
			render: (row) => (
				<Link
					href={row.url}
					target="_blank"
					rel="noopener"
					onClick={(e) => e.stopPropagation()}
					sx={{ display: "inline-flex", alignItems: "center", gap: 0.5 }}
				>
					{row.title}
					<OpenInNewIcon sx={{ fontSize: 14 }} />
				</Link>
			),
		},
		{ key: "description", label: "Description", render: (row) => row.description || "—" },
		{
			key: "category",
			label: "Category",
			render: (row) => <Chip label={row.category} size="small" />,
		},
		...(isAdmin
			? [
				{
					key: "visibility",
					label: "Visible To",
					render: (row) => {
						const staff = row.visibility === "all_staff" ? "All staff" : (row.teacher_names.join(", ") || "No one yet");
						return row.visible_to_families ? `${staff} + Families` : staff;
					},
				},
			]
			: []),
	];

	return (
		<Box>
			<PageHeader
				title="Content"
				onAdd={isAdmin ? () => setShowForm(true) : undefined}
				addLabel="Add Content"
			/>

			<DataTable
				columns={columns}
				data={items}
				loading={loading}
				onDelete={isAdmin ? setDeleteTarget : undefined}
				onRowClick={isAdmin ? (row) => setEditTarget(row) : undefined}
				emptyMessage="No content yet. Add Google Drive links to manuals, curriculum, and forms."
			/>

			{showForm && (
				<ContentItemDialog
					open={showForm}
					onClose={() => setShowForm(false)}
					onSubmit={async (form) => {
						await contentItemsApi.create(form);
						loadItems();
					}}
					teachers={teachers}
					title="Add Content"
				/>
			)}

			{editTarget && (
				<ContentItemDialog
					key={editTarget.id}
					open={!!editTarget}
					onClose={() => setEditTarget(null)}
					onSubmit={async (form) => {
						await contentItemsApi.update(editTarget.id, form);
						setEditTarget(null);
						loadItems();
					}}
					initial={editTarget}
					teachers={teachers}
					title="Edit Content"
				/>
			)}

			<ConfirmDialog
				open={!!deleteTarget}
				onClose={() => setDeleteTarget(null)}
				onConfirm={async () => {
					await contentItemsApi.delete(deleteTarget.id);
					setDeleteTarget(null);
					loadItems();
				}}
				title="Delete Content"
				message={`Remove "${deleteTarget?.title}" from the portal? The file itself stays in Google Drive.`}
			/>
		</Box>
	);
}
