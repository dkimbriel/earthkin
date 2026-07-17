import { Box, Typography, Paper, Chip, Divider, Link as MuiLink } from "@mui/material";
import { useAuth } from "../../contexts/AuthContext";

// The in-app handbook. Sections are tagged by role so each login sees the
// parts relevant to them. Screenshots live in public/help/.

const S = (id, title, roles, body) => ({ id, title, roles, body });
const p = (text) => ({ type: "p", text });
const list = (...items) => ({ type: "list", items });
const steps = (...items) => ({ type: "steps", items });
const img = (src, alt) => ({ type: "img", src: `/help/${src}.png`, alt });
const note = (text) => ({ type: "note", text });

const SECTIONS = [
	S("getting-started", "Getting Started", ["admin", "teacher", "parent"], [
		p("Sign in with your email address and password. If you've forgotten your password (or were just added and never set one), use the “Forgot password?” link on the sign-in screen — it emails you a secure reset link."),
		list(
			"Admins can see and manage everything in the portal.",
			"Teachers get a view-only window into the calendar, programs, families, staff, and shared content.",
			"Parents get their own family portal: enrollments, calendar, payments, and forms."
		),
		note("Keep your password private. Admin accounts can view family and payment information."),
	]),

	S("pipeline", "The Enrollment Pipeline", ["admin"], [
		p("Every family moves through a series of stages, from application to enrolled. The portal tracks each family's stage and sends the right email at each step. You advance a family by opening their application (Enrollments → click the family) and clicking the button for the next step."),
		img("enrollments-list", "Enrollment applications list with stage filters"),
		steps(
			"New application (Submitted) — a family submits the public form. Open it, read their answers, and click Mark as Reviewed.",
			"Invite to a Meet & Greet — click Send Meeting Invite, choose a location and propose 2–5 date options. The family clicks a date in the email; the portal books it and sends a confirmation automatically.",
			"Hold the meeting — after meeting the family, click Complete Meeting with your notes. The portal automatically sends the enrollment fee email. If the meeting didn't go well, click Decline instead — completing the meeting always sends the fee request.",
			"Collect the fee — click Record Fee Payment and pick the family's payment plan and method. The portal creates the family, child, enrollment, payment schedule, and a parent login automatically.",
			"Send enrollment forms — click Send Enrollment Forms. The four forms are issued to the family's parent portal for e-signature (see Enrollment Forms & E-Signatures below).",
			"Confirm enrollment — once all forms are signed, click Confirm Enrollment. The child is officially enrolled and the family gets a confirmation email."
		),
		img("application-detail", "An application's detail page with workflow actions"),
		p("You can Decline an application at any stage with a reason — declined families stay on record but leave the active pipeline. You can also invite a family directly: they get a “You're Invited to Apply” email with a link straight to the application form."),
	]),

	S("communications", "Communications & the Email Log", ["admin"], [
		p("Every application has a Communications tab showing its email timeline: what was sent, when, and whether it delivered. The send buttons there open a compose window pre-filled with the email for that family — names, amounts, and links already filled in — so you can adjust the wording before it goes out, or save it as a draft to finish later."),
		p("The Emails page (left menu) is the school-wide view: every email sent with its status and a preview, your drafts, and the template editor. You can also write a brand-new email from scratch there — pick a parent (or type any address), optionally start from a template, and send."),
		img("emails-log", "The Emails page showing the send log"),
		note("Emails send through the school Gmail account connected under Integrations. If emails show as failed, check that Gmail is still connected."),
	]),

	S("templates", "Editing Email Templates", ["admin"], [
		p("Emails → Templates lists every email the portal sends, pre-filled with its current wording. Click one to edit the subject and body. The green chips are tokens — placeholders like the parent's name or the payment link that get filled in automatically when each email is sent. Click a token to insert it at your cursor. Tokens can be deleted or moved but not mistyped, so you can't accidentally break an email."),
		img("template-editor", "The template editor with token chips"),
		list(
			"Deleting a workflow template resets it to the built-in default wording — safe to experiment.",
			"Templates without a workflow assignment are reusable starting points for manual emails.",
			"The meet-n-greet invite's “date options” token expands to the clickable date links the family chooses from."
		),
	]),

	S("email-tokens", "Email Tokens — What They Mean & How to Adjust Per Family", ["admin"], [
		p("Tokens are the {{double-brace}} placeholders in an email template. When an email is sent, each token is replaced with real information for that specific family — you never type a family's name or amount into a template by hand. In the template editor, hover any token chip to see where its value comes from, and the same descriptions are listed right below the chips."),
		p("Where the values come from:"),
		list(
			"Family & child details (parent name, child name) — from the family's enrollment application.",
			"Program details (program name, dates, class days, times) — from the Program record.",
			"Tuition — the family's tuition: a custom tuition if you've set one on their application, otherwise the program's standard rate.",
			"Enrollment fee — a custom fee if set on the application, otherwise the program default ($150).",
			"Links (enrollment link, payment link, login link) — generated automatically and unique to each family.",
			"Meeting details (date/time, location) — from the meet-and-greet you scheduled.",
			"Family Handbook link — set once for the whole school.",
		]),
		p("To adjust information for ONE family (without changing the template for everyone), you have two options:"),
		steps(
			"Change an amount for a family: open their application → Tuition tab → Edit Fees, and set a custom enrollment fee and/or custom tuition. The {{tuition}} and {{enrollment_fee}} tokens will then show that family's custom amount everywhere.",
			"Change the wording for a one-off message: open the application → Communications tab and click the email you want. It opens a composer pre-filled with that family's email, tokens already filled in — edit any text freely, then send. This changes only that one message, not the saved template.",
		),
		p("Editing a template under Emails → Templates changes it for ALL families going forward. Use the per-family options above when only one family's communication needs to differ."),
	]),

	S("esign", "Enrollment Forms & E-Signatures", ["admin"], [
		p("The four enrollment forms — Family Agreement & Waiver, Parent/Guardian Contact, Medication Administration, and Health & Medical Care — are signed electronically in the parent portal. When you click Send Enrollment Forms on an application (or Issue Enrollment Forms on a family page), pending forms appear in that family's portal."),
		p("Parents read each form, type their full legal name, and sign. Each signature records who signed, when, from where, and an exact snapshot of the form text they agreed to. Signed paperwork lives on the family page, listed under each child."),
		img("family-detail", "A family page with enrollment paperwork status per child"),
		p("Edit the text of the four forms under Emails → Enrollment Forms. Parents signing after an edit always sign (and store) the text as it read at that moment."),
		img("enrollment-form-text", "Editing enrollment form text"),
	]),

	S("programs", "Programs, Classes & Payment Plans", ["admin"], [
		p("Each program holds its dates, capacity, class days and times, enrollment fee, classes, teachers, enrollments, and payment plans. From a program page you can copy the public enrollment application link, invite families directly, and manage everything about the program."),
		img("program-detail", "A program page with classes, enrollments, and payment plans"),
		list(
			"Generate classes from a pattern: instead of adding classes one by one, click Generate from Pattern, pick the weekdays, date range, location, and any holiday dates to skip — the portal creates the whole schedule at once (dates that already have a class are skipped).",
			"Payment plans: due dates anchor to the program start date — a program starting on the 24th bills on the 24th of each month. You can also attach a plan to an enrollment manually from the enrollment page, with optional custom amounts.",
			"Custom pricing: on an individual application you can set a custom enrollment fee or tuition (scholarships, sibling discounts) — it only affects that family."
		),
	]),

	S("calendar", "Calendar & School Events", ["admin", "teacher"], [
		p("The calendar shows class days (blue), meet & greets (green), and school events (purple). Admins can add events — open house, field trips, parent meetings — with Add Event, and flip on “Publish to parent portal calendar” to make an event visible to families (published events show a star)."),
		img("calendar", "The staff calendar with classes, meetings, and school events"),
	]),

	S("content", "Content Library", ["admin", "teacher"], [
		p("The Content page holds links to shared documents in Google Drive — manuals, curriculum, forms, policies. Admins add and organize items; each item is visible either to all staff or only to specific teachers. The files themselves stay in Google Drive; the portal links to them."),
		img("content-library", "The shared content library"),
	]),

	S("users", "Users & Permissions", ["admin"], [
		p("The Users page manages who can sign in and what they can do. Every user has a role:"),
		list(
			"Admin — full access to everything.",
			"Teacher — view-only access to the staff portal (calendar, programs, families, staff, their content). Link a teacher login to their teacher record so their profile connects.",
			"Parent — their own family portal only. Parent logins are created automatically during enrollment; they can never see other families' information."
		),
		p("To add a teacher login: Users → Add User, enter their email, pick the Teacher role, and link their teacher record. Leave the password blank and they'll set their own via the “Forgot password?” link."),
		img("users", "The Users admin page"),
	]),

	S("parent-portal", "The Parent Portal", ["admin", "parent"], [
		p("Families sign in to a portal scoped to just their own household:"),
		list(
			"Home — their children, enrollment status, and family contacts.",
			"Calendar — class days for their enrolled programs plus published school events.",
			"Payments — the next payment due (front and center), the full payment schedule with what's paid and what's coming, and a history of completed payments.",
			"Forms — enrollment forms waiting for signature, and completed ones with their signed record."
		),
		img("parent-payments", "The parent Payments page with the next payment due"),
		img("parent-forms", "The parent Forms page for e-signing"),
	]),

	S("teacher-view", "The Teacher View", ["admin", "teacher"], [
		p("Teachers see the calendar, programs, families, the staff list, and content shared with them. Everything is read-only: teachers can look up family contact information, class schedules, and program details, but only admins can make changes. Teachers can edit their own profile (photo, bio, contact info) from the Teachers page."),
		img("teacher-calendar", "A teacher's view of the portal"),
	]),

	S("support", "Support", ["admin", "teacher", "parent"], [
		p("Questions about enrollment, payments, or forms? Contact the school at earthkinnatureschool@gmail.com."),
		p("For anything technical — the web address, email connection, or unexpected errors — contact David Kimbriel (dkimbriel@gofreedompower.com), who set up the portal."),
	]),
];

function Body({ block }) {
	switch (block.type) {
		case "p":
			return <Typography sx={{ mb: 2 }}>{block.text}</Typography>;
		case "note":
			return (
				<Typography sx={{ mb: 2, fontStyle: "italic" }} color="text.secondary">
					{block.text}
				</Typography>
			);
		case "list":
			return (
				<Box component="ul" sx={{ mb: 2, pl: 3 }}>
					{block.items.map((item, i) => (
						<Typography key={i} component="li" sx={{ mb: 0.5 }}>
							{item}
						</Typography>
					))}
				</Box>
			);
		case "steps":
			return (
				<Box component="ol" sx={{ mb: 2, pl: 3 }}>
					{block.items.map((item, i) => (
						<Typography key={i} component="li" sx={{ mb: 1 }}>
							{item}
						</Typography>
					))}
				</Box>
			);
		case "img":
			return (
				<Box
					component="img"
					src={block.src}
					alt={block.alt}
					loading="lazy"
					sx={{
						width: "100%",
						borderRadius: 2,
						border: "1px solid",
						borderColor: "divider",
						mb: 2,
						display: "block",
					}}
				/>
			);
		default:
			return null;
	}
}

export default function HelpCenterPage() {
	const { user } = useAuth();
	const role = user?.role || "parent";
	const sections = SECTIONS.filter((s) => s.roles.includes(role));

	return (
		<Box sx={{ maxWidth: 900, mx: "auto" }}>
			<Typography variant="h4" gutterBottom>
				Help Center
			</Typography>
			<Typography color="text.secondary" sx={{ mb: 3 }}>
				How to use the Earthkin portal
				{role === "admin" ? " — the full admin guide." : role === "teacher" ? " — for teachers." : " — for families."}
			</Typography>

			<Paper variant="outlined" sx={{ p: 2, mb: 3 }}>
				<Typography variant="subtitle2" gutterBottom>
					In this guide
				</Typography>
				<Box sx={{ display: "flex", gap: 1, flexWrap: "wrap" }}>
					{sections.map((s) => (
						<Chip
							key={s.id}
							label={s.title}
							size="small"
							component={MuiLink}
							href={`#${s.id}`}
							clickable
						/>
					))}
				</Box>
			</Paper>

			{sections.map((section) => (
				<Paper key={section.id} id={section.id} sx={{ p: 3, mb: 3, scrollMarginTop: "120px" }}>
					<Typography variant="h5" gutterBottom>
						{section.title}
					</Typography>
					<Divider sx={{ mb: 2 }} />
					{section.body.map((block, i) => (
						<Body key={i} block={block} />
					))}
				</Paper>
			))}
		</Box>
	);
}
