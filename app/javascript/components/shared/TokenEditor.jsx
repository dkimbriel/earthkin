import { useRef, useEffect, forwardRef, useImperativeHandle } from "react";
import { Box, Typography } from "@mui/material";

// A contenteditable field where {{tokens}} render as atomic chips: they can
// be deleted or moved as a unit but their text can't be edited, so a template
// can't be broken by removing a brace or renaming a variable.

const escapeHtml = (s) =>
	s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const CHIP_STYLE = [
	"display:inline-block",
	"background:#e8f5e9",
	"color:#2e7d32",
	"border:1px solid #a5d6a7",
	"border-radius:12px",
	"padding:0 8px",
	"margin:0 2px",
	"font-size:0.8em",
	"line-height:1.6",
	"user-select:none",
	"white-space:nowrap",
].join(";");

const chipHtml = (token) =>
	`<span data-token="${token}" contenteditable="false" style="${CHIP_STYLE}">${escapeHtml(token.replace(/_/g, " "))}</span>`;

const valueToHtml = (value) =>
	(value || "")
		.split("\n")
		.map((line) =>
			line
				.split(/({{\s*\w+\s*}})/g)
				.map((part) => {
					const match = part.match(/^{{\s*(\w+)\s*}}$/);
					return match ? chipHtml(match[1]) : escapeHtml(part);
				})
				.join("")
		)
		.join("<br>");

const serializeNode = (node) => {
	let out = "";
	node.childNodes.forEach((child) => {
		if (child.nodeType === Node.TEXT_NODE) {
			out += child.textContent;
		} else if (child.nodeName === "BR") {
			out += "\n";
		} else if (child.dataset && child.dataset.token) {
			out += `{{${child.dataset.token}}}`;
		} else {
			// Block elements (divs the browser inserts on Enter) start a new line.
			if (out && !out.endsWith("\n")) out += "\n";
			out += serializeNode(child);
		}
	});
	return out;
};

const TokenEditor = forwardRef(function TokenEditor(
	{ label, value, onChange, multiline = false, minRows = 10, onFocus },
	ref
) {
	const editorRef = useRef(null);
	const lastSerialized = useRef(null);

	useEffect(() => {
		if (editorRef.current && lastSerialized.current !== value) {
			editorRef.current.innerHTML = valueToHtml(value);
			lastSerialized.current = value;
		}
	}, [value]);

	const emitChange = () => {
		const serialized = serializeNode(editorRef.current).replace(/\n$/, "");
		lastSerialized.current = serialized;
		onChange(serialized);
	};

	useImperativeHandle(ref, () => ({
		insertToken(token) {
			const editor = editorRef.current;
			if (!editor) return;
			editor.focus();

			const selection = window.getSelection();
			let range =
				selection.rangeCount > 0 && editor.contains(selection.anchorNode)
					? selection.getRangeAt(0)
					: null;
			if (!range) {
				range = document.createRange();
				range.selectNodeContents(editor);
				range.collapse(false);
			}

			range.deleteContents();
			const template = document.createElement("template");
			template.innerHTML = chipHtml(token);
			const chipNode = template.content.firstChild;
			range.insertNode(chipNode);
			range.setStartAfter(chipNode);
			range.collapse(true);
			selection.removeAllRanges();
			selection.addRange(range);

			emitChange();
		},
	}));

	const handleKeyDown = (e) => {
		if (!multiline && e.key === "Enter") {
			e.preventDefault();
		}
	};

	const handlePaste = (e) => {
		e.preventDefault();
		const text = e.clipboardData.getData("text/plain");
		document.execCommand("insertText", false, text);
	};

	return (
		<Box>
			<Typography variant="caption" color="text.secondary">
				{label}
			</Typography>
			<Box
				ref={editorRef}
				contentEditable
				suppressContentEditableWarning
				onInput={emitChange}
				onKeyDown={handleKeyDown}
				onPaste={handlePaste}
				onFocus={onFocus}
				sx={{
					border: "1px solid",
					borderColor: "divider",
					borderRadius: 1,
					px: 1.5,
					py: 1,
					fontSize: "0.95rem",
					lineHeight: 1.7,
					minHeight: multiline ? `${minRows * 1.7}em` : "auto",
					whiteSpace: "pre-wrap",
					overflowY: multiline ? "auto" : "hidden",
					"&:focus": {
						outline: "none",
						borderColor: "primary.main",
						boxShadow: (theme) => `0 0 0 1px ${theme.palette.primary.main}`,
					},
				}}
			/>
		</Box>
	);
});

export default TokenEditor;
