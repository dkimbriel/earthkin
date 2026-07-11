class SeedEnrollmentFormTexts < ActiveRecord::Migration[7.0]
	# Imports the four enrollment form texts from the school's Google Docs into
	# the e-signable form templates. Only fills templates that still have
	# placeholder text — an admin-edited body is never overwritten.

	class MigrationFormTemplate < ActiveRecord::Base
		self.table_name = 'form_templates'
	end

	PLACEHOLDER_MARKER = '(Form text not set yet'

	FAMILY_AGREEMENT = <<~TEXT
		Earthkin Nature School Family Agreement and Waiver

		FAMILY AND SCHOOL AGREEMENT

		This agreement is between Earthkin Nature School and the parent/legal guardian of the child named on this form.

		Enrollment Obligation
		Enrollment at the School is a commitment for the full school year. Upon enrollment, families reserve their child's space in the program and agree to fulfill tuition obligations for the academic year. Tuition payments secure staffing, materials, insurance, outdoor equipment, and ongoing program operations, and are not based solely on attendance. Tuition remains due regardless of absences, illness, vacations, weather-related closures, or other missed days. By enrolling, families acknowledge and agree to abide by all school policies, tuition schedules, and enrollment agreements outlined in the Family Handbook.

		Enrollment Fee
		A $150 non-refundable enrollment fee is required for the School to reserve a place for your child in the program.

		Tuition Obligation
		Tuition amount is $2,800 for the Nature Preschool program. Tuition can be paid by check, cash, or Venmo. Parent has selected one of the following payment plans for tuition during enrollment:

		- Option 1: Full Payment — one payment of $2,800, due August 1, 2026
		- Option 2: Semester Payments — two payments of $1,400 (Aug 1 and Jan 1)
		- Option 3: Quarterly Payments — four payments of $700 (Aug 1, Oct 1, Jan 1, April 1)
		- Option 4: Monthly Payments — 10 payments of $280 due the first of each month beginning Aug 1 through May 1

		Donations
		One of our goals at the School is making nature-based early learning accessible to more families. Thanks to support from grant funding and generous donors, we are able to offer a subsidized tuition rate that helps keep our program affordable while sustaining our core programming. We encourage families of means to make a donation along with their tuition payment which will further support and expand our programming, allow us to bring in guest teachers and share special offerings, and support a hardship fund for all families. If you would like to make a donation ($50, $100, $150, $250, $500, or another amount), let us know and it will be added to your payment plan.

		Withdrawal Procedure
		Families withdrawing during the school year are required to provide 90 days written notice and remain responsible for tuition during the notice period. Enrollment fees are nonrefundable. Families who withdraw without providing the required 90 days notice will be charged a $450 cancellation fee, made payable immediately. Exceptions to the cancellation fee may be considered on a case-by-case basis.

		Our withdrawal policy helps sustain the consistency and quality of our program because:
		- Staffing ratios are fixed to ensure safe, supportive care for children
		- Replacing a child's spot after the school year begins is often difficult
		- Outdoor programs maintain ongoing costs for insurance, gear, staffing, and programming regardless of attendance

		Payment, Late Fees, and Default
		I understand that a late charge of $5 per day will apply to any overdue payment. A payment plan must be set up if payment is more than one week in arrears. After the second week, if the payment plan is not being adhered to or the balance has not been paid, the child will not be allowed to attend class. We genuinely want to work with our families. Please keep us informed of any special circumstances, so we can work with you as best as we can.

		School Rules
		I agree that my child and I will abide by the rules, regulations, and conditions contained in the School's Family Handbook and other published documents which may be amended from time to time.

		School Support
		I agree to support the School in its philosophy, methods, objectives, and policies. I also agree to maintain a positive attitude and keep in regular contact with teachers. I understand that I am highly encouraged by the School's leadership team to participate in volunteer days and contribute to fundraising efforts for the school when I am able.

		Privacy and Media Use Policy
		At Earthkin Nature School, we are committed to protecting the privacy, dignity, and safety of every child and family in our community. We practice faceless marketing, meaning children's faces and identifying features will never be shown in public-facing materials.

		Non-identifiable photos, videos, or recordings may be used in promotional materials, including the school's website, social media, printed materials, and newsletters shared with enrolled families. Earthkin Nature School will never use a child's full name alongside identifiable images in public materials, and all media will be handled with care and respect for family privacy.

		Media preference: unless you tell us otherwise in writing, signing this form GIVES permission for Earthkin Nature School to use non-identifiable photographs, videos, or recordings of your child for newsletters, internal communications, promotional materials, the school website, and social media in accordance with the school's faceless marketing policy. If you DO NOT give permission, reply to your enrollment email or write to earthkinnatureschool@gmail.com and we will exclude your child from all media whenever reasonably possible. If you choose to opt out, we encourage you to talk with your child about your family's decision and ask them, when possible, to step out of group photos or recordings to help us honor your preference without singling them out.

		Termination of Student's Attendance
		The School has the right to suspend or terminate the attendance of my child for reasons set forth in the Family Handbook (or other published document), for reasons that the School considers detrimental to the School community, student, or other students, or for the failure to pay all or any part of the financial obligations for attendance. The School will work with the family to resolve any issues that may lead to the suspension or termination of a child from the school.

		Medical Authorization
		If, in the opinion of a properly licensed and practicing physician, my child needs emergency medical or surgical services which require a parent's pre-authorization or consent, I authorize the School to furnish such consent on my behalf. I hold the School harmless from any liability which might arise from the giving of such consent.

		Consent to Medical Care
		I authorize the School to supply medical care as needed for my child (including administration of allergy medications, Epi-Pens, etc.), according to a prescription from a licensed practitioner, or other minor medical care or emergency as determined to be appropriate by the School Staff. I release and hold the School harmless from any liability which might arise from the provision of such medical care.

		Inclement Weather/Acts of God
		The School's duties and obligations shall be suspended immediately during all periods that the school is closed because of force majeure events including, but not limited to, any fire, act of God, earthquake, war, governmental action, act of terrorism, epidemic, pandemic or any other event beyond the School's control. If such an event occurs, the School's duties and obligations will be postponed until such time as the School, in its sole discretion, may safely reopen. While every attempt will be made to make up any days missed, the School is under no obligation to refund any portion of the tuition paid.

		WAIVER AND RELEASE

		RISK FACTORS: The undersigned acknowledges the games and activities conducted by EARTHKIN NATURE SCHOOL NONPROFIT and its agents will necessarily involve the use of natural materials and other props that may cause injury to your child if handled inappropriately by your child or by another child, and participation in any program provided by EARTHKIN NATURE SCHOOL NONPROFIT necessarily involves risks such as, but not limited to, bodily injury, death, or property damage which might result from the use of equipment or facilities, from the activity itself, from the acts of others or animals, or from the unavailability of emergency or emergency medical care.

		ASSUMPTION OF ALL RISKS: Understanding the above risks factors, the undersigned recognizes and assumes all risks that arise out of their child's participation and presence at EARTHKIN NATURE SCHOOL NONPROFIT facilities, functions, or other forums and specifically, but not limited to, injury or death from the use of any of EARTHKIN NATURE SCHOOL NONPROFIT'S equipment, use of its facilities, from the activity itself, the act of others or animals, or the unavailability of emergency care, including but not limited to, those risk factors described above.

		RELEASE: The undersigned releases EARTHKIN NATURE SCHOOL NONPROFIT, its agents, employees, or volunteers, as well as all heirs, executors, administrators and assigns and agrees not to sue them on account of or in conjunction with any claims, causes of action, injuries, damage, cost of expenses arising out of the activities referenced herein, including those claims based on death, bodily injury, or property damage whether or not caused by the acts, omissions or other fault of the parties being released.

		WAIVER: The undersigned waives the protection afforded by any statute or law in any jurisdiction in the State of Virginia which purpose, substance, and/or effect is to provide that a general release shall not extend to claims, material or otherwise which the person giving the release does not know of or suspect at the time of executing the release. This means, in part, that the undersigned is releasing unknown future claims.

		I, as the parent or legal guardian of the child named on this form, hereby waive, release, and shall hold harmless EARTHKIN NATURE SCHOOL NONPROFIT, Mrs. Sydney Gary, any employee, agent, or volunteer for EARTHKIN NATURE SCHOOL NONPROFIT, and any other parent, teacher, helper, child or adult participating in a EARTHKIN NATURE SCHOOL NONPROFIT program, from any injury to me, my family members or my child, or loss of property or other damage resulting from my or my child's participation in any EARTHKIN NATURE SCHOOL NONPROFIT program, activity, service or event. Similarly, I specifically waive any claim, be it legal, equitable, or administrative in any federal, state, or local forum against EARTHKIN NATURE SCHOOL NONPROFIT, Mrs. Gary, or any other parent, teacher, helper, or other child or adult participating in an EARTHKIN NATURE SCHOOL NONPROFIT program, activity, service or event.

		By signing below, I confirm that I have read, understand, and agree to the Family Agreement and the Waiver and Release above. Typing my full legal name constitutes my electronic signature.
	TEXT


	HEALTH_MEDICAL_CARE = <<~TEXT
		Health and Medical Care Form

		This form helps us keep your child safe, supported, and well while in our care. All information will be kept confidential and used only by staff for emergency or health-related purposes.

		HOW TO COMPLETE THIS FORM: answer the numbered questions below in the "Your answers" box before signing. Copy each number so we can match your answers to the questions.

		1. Child's full name, date of birth, and preferred name
		2. Home address
		3. Parent/guardian name, primary phone, and email
		4. Primary care provider and their phone number
		5. Insurance provider and policy number (policy number optional)
		6. Does your child have any of the following: asthma, allergies (food, insect, environmental), eczema or skin sensitivities, seizures, diabetes, or other ongoing medical condition(s)? If so, please describe.
		7. Allergies — list all known allergies, the reaction type, and treatment (e.g., EpiPen, antihistamine)
		8. Does your child take any medications regularly? If yes, list each medication's name, dose, time(s) given, and purpose. Will any medication need to be administered during program hours? (If yes, also complete the Medication Administration Form and provide medication in its original container with your child's name and dosage instructions clearly labeled.)
		9. We spend 100% of our time outdoors in all types of weather. Does your child have any environmental sensitivities (e.g., to pollen, sun exposure, insect bites, cold, heat)? Does your child require sunscreen, bug repellent, or other topical applications? If yes, please specify brand, preferences, or guidance.
		10. Social & emotional health — are there any strategies, comfort items, or routines that help your child feel safe and supported when upset, tired, or in a new environment?
		11. Optional — holistic/family health notes: if your family follows particular health practices or preferences (e.g., herbal remedies, dietary choices, spiritual considerations), please share any information that will help us honor your child's wellbeing holistically.

		EMERGENCY MEDICAL AUTHORIZATION
		In the event of an emergency where I cannot be reached, I authorize Earthkin Nature School staff to obtain emergency medical care for my child, including transportation by ambulance and treatment at a hospital or urgent care center.

		PARENTAL ACKNOWLEDGMENT
		I understand that the staff of Earthkin Nature School are trained in basic first aid and CPR. I give permission for staff to provide minor first aid (e.g., cleaning scrapes, applying bandages, removing splinters) as needed.

		Thank you for taking the time to complete this form. Your child's safety and wellbeing are our top priority — and by understanding their individual needs, we can ensure they thrive in nature each day.

		By signing, I confirm the information I have provided is accurate and I agree to the authorizations above.
	TEXT

	MEDICATION_ADMINISTRATION = <<~TEXT
		Medication Administration Form

		This form must be completed for each medication your child needs while in our care. All medications must be in their original, labeled containers and given directly to staff. Medications are stored securely and administered according to the instructions below.

		HOW TO COMPLETE THIS FORM: answer the numbered questions below in the "Your answers" box before signing. Copy each number so we can match your answers to the questions. If your child needs more than one medication, sign this form for the first and contact the school to issue another.

		1. Child's full name and date of birth
		2. Medication name
		3. Dosage (amount)
		4. Route (how it's given): by mouth, topical, inhaled, or other
		5. Reason for medication
		6. Time(s) to be administered
		7. Start date and end date
		8. Special instructions (e.g., take with food, shake well, storage needs)
		9. Possible side effects or reactions — common or expected effects, adverse reactions requiring medical attention, and the action to take if a reaction occurs
		10. Prescribing physician's name, phone, and office address
		11. Is this a prescribed medication, or an over-the-counter medication (administered with parent consent)?
		12. Parent/guardian phone number

		PARENT/GUARDIAN AUTHORIZATION
		I authorize Earthkin Nature School staff to administer the medication described above as instructed. I understand:
		- Medication will only be given according to these written directions.
		- All medications must be provided in their original containers, clearly labeled with my child's name.
		- I will notify staff immediately of any changes to this medication or dosage.

		At Earthkin Nature School, we approach each child's health with care and mindfulness. Thank you for your partnership in supporting your child's wellbeing.
	TEXT

	PARENT_GUARDIAN_CONTACT = <<~TEXT
		Parent/Guardian Contact Form

		HOW TO COMPLETE THIS FORM: answer the numbered questions below in the "Your answers" box before signing. Copy each number so we can match your answers to the questions.

		1. Child's full name and date of birth
		2. Parent/Guardian 1 — name, relationship to child, primary phone, secondary phone (if applicable), email address, home address, and occupation/workplace (optional)
		3. Parent/Guardian 2 (if applicable) — name, relationship to child, primary phone, secondary phone (if applicable), email address, home address (if different), and occupation/workplace (optional)
		4. Emergency contacts other than parents/guardians (these individuals may be contacted in case of emergency if parents/guardians are unavailable) — for each: name, relationship to child, and phone
		5. Authorized pick-up persons — anyone other than parents/guardians who is permitted to pick up your child — for each: name, relationship, and phone
		6. Communication preferences — text message, email, phone call, or other (list all that apply)
		7. Preferred parent/guardian for primary contact
		8. Family notes or special considerations — anything you'd like our staff to know (cultural traditions, family dynamics, or preferred communication styles)

		I certify that the information above is accurate and will notify Earthkin Nature School of any changes.
	TEXT

	FORM_BODIES = {
		'family_agreement' => ['Family Agreement & Waiver', FAMILY_AGREEMENT],
		'health_medical_care' => ['Health & Medical Care Form', HEALTH_MEDICAL_CARE],
		'medication_administration' => ['Medication Administration Form', MEDICATION_ADMINISTRATION],
		'parent_guardian_contact' => ['Parent/Guardian Contact Form', PARENT_GUARDIAN_CONTACT]
	}.freeze

	def up
		FORM_BODIES.each do |key, (name, body)|
			template = MigrationFormTemplate.find_or_initialize_by(key: key)
			template.name = name if template.name.blank?

			# Don't clobber wording an admin has already customized.
			if template.new_record? || template.body.blank? || template.body.include?(PLACEHOLDER_MARKER)
				template.body = body.strip
				template.save!
			end
		end
	end

	def down
		# Content seed — nothing sensible to revert to.
	end
end
