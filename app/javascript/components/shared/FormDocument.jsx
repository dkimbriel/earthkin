import { Box, Typography, TextField, Checkbox, FormControlLabel, Divider } from "@mui/material";

// Renders an enrollment form document: a markdown subset (headings, bold,
// lists, dividers) with inline fill-in fields where the paper form had
// blanks. Marker syntax, usable from the admin form-text editor:
//   [[text:key|Label]]        inline text input
//   [[textarea:key|Label]]    multi-line input (own block)
//   [[checkbox:key|Label]]    checkbox
//   [[signature]]             the legal signature line (typed name, cursive)
//   [[date]]                  the signing date
export const SIGNATURE_FONT = '"Snell Roundhand", "Savoye LET", "Brush Script MT", "Segoe Script", cursive';

export const hasFormFields = (body) => /\[\[(text|textarea|checkbox|signature)/.test(body || "");

const FIELD_RE = /\[\[(text|textarea|checkbox|signature|date)(?::([\w-]+))?(?:\|([^\]]*))?\]\]/g;
const BOLD_RE = /\*\*(.+?)\*\*/g;

const renderBold = (text, keyPrefix) => {
	const parts = text.split(BOLD_RE);
	return parts.map((part, i) =>
		i % 2 === 1 ? <strong key={`${keyPrefix}-b${i}`}>{part}</strong> : part
	);
};

function InlineField({ type, fieldKey, label, values, onChange, readOnly }) {
	const value = values?.[fieldKey];

	if (type === "checkbox") {
		if (readOnly) {
			return (
				<Typography component="span" sx={{ mr: 1 }}>
					{value ? "☑" : "☐"} {label}
				</Typography>
			);
		}
		return (
			<FormControlLabel
				sx={{ display: "flex", alignItems: "flex-start", ml: 0, my: 0.25, "& .MuiCheckbox-root": { py: 0.25 } }}
				control={
					<Checkbox
						size="small"
						checked={!!value}
						onChange={(e) => onChange(fieldKey, e.target.checked)}
					/>
				}
				label={label}
			/>
		);
	}

	if (readOnly) {
		return (
			<Typography
				component="span"
				sx={{
					borderBottom: "1px solid",
					borderColor: "text.disabled",
					px: 0.5,
					minWidth: 120,
					display: "inline-block",
					fontStyle: value ? "normal" : "italic",
					color: value ? "text.primary" : "text.disabled",
					whiteSpace: type === "textarea" ? "pre-wrap" : "normal",
				}}
			>
				{value || "not provided"}
			</Typography>
		);
	}

	if (type === "textarea") {
		return (
			<TextField
				label={label}
				value={value || ""}
				onChange={(e) => onChange(fieldKey, e.target.value)}
				multiline
				minRows={3}
				fullWidth
				size="small"
				sx={{ my: 1 }}
			/>
		);
	}

	return (
		<TextField
			placeholder={label}
			value={value || ""}
			onChange={(e) => onChange(fieldKey, e.target.value)}
			variant="standard"
			size="small"
			sx={{ mx: 0.5, minWidth: 220, verticalAlign: "baseline" }}
		/>
	);
}

function SignatureBlock({ readOnly, signatureName, onSignatureChange, signedAt }) {
	return (
		<Box id="form-signature-block" sx={{ my: 2, p: 2, border: "1px dashed", borderColor: "divider", borderRadius: 1 }}>
			{readOnly ? (
				<>
					<Typography sx={{ fontFamily: SIGNATURE_FONT, fontSize: "2rem", lineHeight: 1.2 }}>
						{signatureName || " "}
					</Typography>
					<Typography variant="caption" color="text.secondary">
						Parent/Guardian signature
						{signedAt ? ` — signed ${new Date(signedAt).toLocaleString()}` : ""}
					</Typography>
				</>
			) : (
				<>
					<TextField
						label="Type your full legal name to sign"
						value={signatureName || ""}
						onChange={(e) => onSignatureChange(e.target.value)}
						required
						fullWidth
						sx={{ mb: 1 }}
					/>
					<Typography sx={{ fontFamily: SIGNATURE_FONT, fontSize: "2rem", lineHeight: 1.2, minHeight: 48 }}>
						{signatureName || " "}
					</Typography>
					<Typography variant="caption" color="text.secondary">
						Signature preview — date: {new Date().toLocaleDateString()}
					</Typography>
				</>
			)}
		</Box>
	);
}

export default function FormDocument({
	body,
	values = {},
	onChange = () => {},
	readOnly = false,
	signatureName = "",
	onSignatureChange = () => {},
	signedAt = null,
}) {
	const renderInline = (text, keyPrefix) => {
		const nodes = [];
		let lastIndex = 0;
		let match;
		const re = new RegExp(FIELD_RE.source, "g");
		let i = 0;
		while ((match = re.exec(text)) !== null) {
			if (match.index > lastIndex) {
				nodes.push(renderBold(text.slice(lastIndex, match.index), `${keyPrefix}-t${i}`));
			}
			const [, type, fieldKey, label] = match;
			if (type === "signature") {
				nodes.push(
					<SignatureBlock
						key={`${keyPrefix}-sig${i}`}
						readOnly={readOnly}
						signatureName={signatureName}
						onSignatureChange={onSignatureChange}
						signedAt={signedAt}
					/>
				);
			} else if (type === "date") {
				nodes.push(
					<Typography component="span" key={`${keyPrefix}-d${i}`} sx={{ borderBottom: "1px solid", borderColor: "text.disabled", px: 0.5 }}>
						{signedAt ? new Date(signedAt).toLocaleDateString() : new Date().toLocaleDateString()}
					</Typography>
				);
			} else {
				nodes.push(
					<InlineField
						key={`${keyPrefix}-f${i}`}
						type={type}
						fieldKey={fieldKey}
						label={label || fieldKey}
						values={values}
						onChange={onChange}
						readOnly={readOnly}
					/>
				);
			}
			lastIndex = match.index + match[0].length;
			i += 1;
		}
		if (lastIndex < text.length) {
			nodes.push(renderBold(text.slice(lastIndex), `${keyPrefix}-tail`));
		}
		return nodes;
	};

	const lines = (body || "").split("\n");
	const blocks = [];
	let paragraph = [];
	let listItems = [];
	let listOrdered = false;

	const flushParagraph = (key) => {
		if (paragraph.length) {
			blocks.push(
				<Typography key={key} paragraph sx={{ mb: 1.5 }}>
					{paragraph.map((line, i) => (
						<Box component="span" key={i} sx={{ display: "block" }}>
							{renderInline(line, `${key}-l${i}`)}
						</Box>
					))}
				</Typography>
			);
			paragraph = [];
		}
	};

	const flushList = (key) => {
		if (listItems.length) {
			blocks.push(
				<Box component={listOrdered ? "ol" : "ul"} key={key} sx={{ pl: 3, mb: 1.5, mt: 0 }}>
					{listItems.map((item, i) => (
						<Typography component="li" key={i} sx={{ mb: 0.5 }}>
							{renderInline(item, `${key}-i${i}`)}
						</Typography>
					))}
				</Box>
			);
			listItems = [];
		}
	};

	lines.forEach((rawLine, idx) => {
		const line = rawLine.trimEnd();
		const key = `blk${idx}`;

		const heading = line.match(/^(#{1,3})\s+(.*)$/);
		const bullet = line.match(/^-\s+(.*)$/);
		const numbered = line.match(/^\d+\.\s+(.*)$/);
		// A checkbox on its own line renders as its own row, not inside a paragraph.
		const soloCheckbox = line.match(/^\[\[checkbox:[\w-]+\|[^\]]*\]\]$/);

		if (heading) {
			flushParagraph(`${key}-p`);
			flushList(`${key}-ul`);
			const level = heading[1].length;
			const variant = level === 1 ? "h5" : level === 2 ? "h6" : "subtitle1";
			blocks.push(
				<Typography key={key} variant={variant} sx={{ mt: level === 3 ? 2 : 3, mb: 1, fontWeight: 600 }}>
					{renderInline(heading[2], key)}
				</Typography>
			);
		} else if (line === "---") {
			flushParagraph(`${key}-p`);
			flushList(`${key}-ul`);
			blocks.push(<Divider key={key} sx={{ my: 2 }} />);
		} else if (bullet || numbered) {
			flushParagraph(`${key}-p`);
			const item = bullet ? bullet[1] : numbered[1];
			const ordered = !!numbered;
			if (listItems.length && listOrdered !== ordered) flushList(`${key}-ul`);
			listOrdered = ordered;
			listItems.push(item);
		} else if (soloCheckbox) {
			flushParagraph(`${key}-p`);
			flushList(`${key}-ul`);
			blocks.push(<Box key={key}>{renderInline(line, key)}</Box>);
		} else if (line.trim() === "") {
			flushParagraph(`${key}-p`);
			flushList(`${key}-ul`);
		} else {
			flushList(`${key}-ul`);
			paragraph.push(line);
		}
	});
	flushParagraph("tail-p");
	flushList("tail-ul");

	return <Box>{blocks}</Box>;
}
