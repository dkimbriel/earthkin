class ConvertFormTextsToStructuredDocuments < ActiveRecord::Migration[7.0]
	# Rewrites the four enrollment forms as structured documents: a markdown
	# subset (headings, bold, lists) with inline field markers so parents fill
	# in blanks and check boxes right where they appear in the original Google
	# Docs. Field syntax: [[text:key|Label]], [[textarea:key|Label]],
	# [[checkbox:key|Label]], [[signature]], [[date]].
	#
	# Admin-customized bodies are never overwritten: only bodies still matching
	# a previous seed (plain-text import or placeholder) are converted.

	class MigrationFormTemplate < ActiveRecord::Base
		self.table_name = 'form_templates'
	end

	# Fingerprints of bodies this migration may safely replace.
	PREVIOUS_SEED_MARKERS = [
		'(Form text not set yet',
		'HOW TO COMPLETE THIS FORM',
		'Media preference: unless you tell us otherwise'
	].freeze

	def change
		add_column :enrollment_form_signatures, :form_fields, :jsonb, null: false, default: {}

		reversible do |dir|
			dir.up { seed_structured_bodies }
		end
	end

	private

	def seed_structured_bodies
		FORM_BODIES.each do |key, body|
			template = MigrationFormTemplate.find_by(key: key)
			next unless template
			next unless template.body.blank? || PREVIOUS_SEED_MARKERS.any? { |m| template.body.include?(m) }

			template.update!(body: body.strip)
		end
	end

	FAMILY_AGREEMENT = <<~TEXT
		# Earthkin Nature School Family Agreement and Waiver

		## Family and School Agreement

		This agreement is between Earthkin Nature School and the parent/legal guardian of [[text:child_full_name|Child's full name]].

		### Enrollment Obligation

		Enrollment at the School is a commitment for the full school year. Upon enrollment, families reserve their child's space in the program and agree to fulfill tuition obligations for the academic year. Tuition payments secure staffing, materials, insurance, outdoor equipment, and ongoing program operations, and are not based solely on attendance. Tuition remains due regardless of absences, illness, vacations, weather-related closures, or other missed days. By enrolling, families acknowledge and agree to abide by all school policies, tuition schedules, and enrollment agreements outlined in the Family Handbook.

		### Enrollment Fee

		A $150 non-refundable enrollment fee is required for the School to reserve a place for your child in the program.

		### Tuition Obligation

		Tuition amount is $2,800 for the Nature Preschool program. Tuition can be paid by check, cash, or Venmo. Parent has selected the following payment plan for tuition (check only one):

		[[checkbox:plan_full|Option 1: Full Payment — one payment of $2,800, due August 1, 2026]]
		[[checkbox:plan_semester|Option 2: Semester Payments — two payments of $1,400 (Aug 1 and Jan 1)]]
		[[checkbox:plan_quarterly|Option 3: Quarterly Payments — four payments of $700 (Aug 1, Oct 1, Jan 1, April 1)]]
		[[checkbox:plan_monthly|Option 4: Monthly Payments — 10 payments of $280 due the first of each month beginning Aug 1 through May 1]]

		### Donations

		One of our goals at the School is making nature-based early learning accessible to more families. Thanks to support from grant funding and generous donors, we are able to offer a subsidized tuition rate that helps keep our program affordable while sustaining our core programming. We encourage families of means to make a donation along with their tuition payment which will further support and expand our programming, allow us to bring in guest teachers and share special offerings, and support a hardship fund for all families. Your selection will be added to your desired payment plan.

		[[checkbox:donation_50|Additional one-time donation of $50]]
		[[checkbox:donation_100|Additional one-time donation of $100]]
		[[checkbox:donation_150|Additional one-time donation of $150]]
		[[checkbox:donation_250|Additional one-time donation of $250]]
		[[checkbox:donation_500|Additional one-time donation of $500]]
		[[checkbox:donation_other|Other amount:]] [[text:donation_other_amount|Other donation amount]]
		[[checkbox:donation_none|I am unable to make a donation at this time]]

		### Withdrawal Procedure

		Families withdrawing during the school year are required to provide 90 days written notice and remain responsible for tuition during the notice period. Enrollment fees are nonrefundable. Families who withdraw without providing the required 90 days notice will be charged a $450 cancellation fee, made payable immediately. Exceptions to the cancellation fee may be considered on a case-by-case basis.

		Our withdrawal policy helps sustain the consistency and quality of our program because:

		- Staffing ratios are fixed to ensure safe, supportive care for children
		- Replacing a child's spot after the school year begins is often difficult
		- Outdoor programs maintain ongoing costs for insurance, gear, staffing, and programming regardless of attendance

		### Payment, Late Fees, and Default

		I understand that a late charge of $5 per day will apply to any overdue payment. A payment plan must be set up if payment is more than one week in arrears. After the second week, if the payment plan is not being adhered to or the balance has not been paid, the child will not be allowed to attend class. We genuinely want to work with our families. Please keep us informed of any special circumstances, so we can work with you as best as we can.

		### School Rules

		I agree that my child and I will abide by the rules, regulations, and conditions contained in the School's Family Handbook and other published documents which may be amended from time to time.

		### School Support

		I agree to support the School in its philosophy, methods, objectives, and policies. I also agree to maintain a positive attitude and keep in regular contact with teachers. I understand that I am highly encouraged by the School's leadership team to participate in volunteer days and contribute to fundraising efforts for the school when I am able.

		### Privacy and Media Use Policy

		At Earthkin Nature School, we are committed to protecting the privacy, dignity, and safety of every child and family in our community. We practice faceless marketing, meaning children's faces and identifying features will never be shown in public-facing materials.

		Non-identifiable photos, videos, or recordings may be used in promotional materials, including the school's website, social media, printed materials, and newsletters shared with enrolled families. Earthkin Nature School will never use a child's full name alongside identifiable images in public materials, and all media will be handled with care and respect for family privacy.

		Please indicate your family's preference below (check one):

		[[checkbox:media_permission|I GIVE permission for Earthkin Nature School to use non-identifiable photographs, videos, or recordings of my child for newsletters, internal communications, promotional materials, the school website, and social media in accordance with the school's faceless marketing policy.]]
		[[checkbox:media_no_permission|I DO NOT GIVE permission for Earthkin Nature School to use any photographs, videos, or recordings of my child for any purpose.]]

		Families who choose to opt out will have their child excluded from all media whenever reasonably possible. If you choose to opt out, we encourage you to talk with your child about your family's decision and ask them, when possible, to step out of group photos or recordings to help us honor your preference without singling them out.

		### Termination of Student's Attendance

		The School has the right to suspend or terminate the attendance of my child for reasons set forth in the Family Handbook (or other published document), for reasons that the School considers detrimental to the School community, student, or other students, or for the failure to pay all or any part of the financial obligations for attendance. The School will work with the family to resolve any issues that may lead to the suspension or termination of a child from the school.

		### Medical Authorization

		If, in the opinion of a properly licensed and practicing physician, my child needs emergency medical or surgical services which require a parent's pre-authorization or consent, I authorize the School to furnish such consent on my behalf. I hold the School harmless from any liability which might arise from the giving of such consent.

		### Consent to Medical Care

		I authorize the School to supply medical care as needed for my child (including administration of allergy medications, Epi-Pens, etc.), according to a prescription from a licensed practitioner, or other minor medical care or emergency as determined to be appropriate by the School Staff. I release and hold the School harmless from any liability which might arise from the provision of such medical care.

		### Inclement Weather/Acts of God

		The School's duties and obligations shall be suspended immediately during all periods that the school is closed because of force majeure events including, but not limited to, any fire, act of God, earthquake, war, governmental action, act of terrorism, epidemic, pandemic or any other event beyond the School's control. If such an event occurs, the School's duties and obligations will be postponed until such time as the School, in its sole discretion, may safely reopen. While every attempt will be made to make up any days missed, the School is under no obligation to refund any portion of the tuition paid.

		[[checkbox:agree_all|I confirm I have read, understand, and agree to all above]]

		## Waiver and Release

		**RISK FACTORS:** The undersigned acknowledges the games and activities conducted by EARTHKIN NATURE SCHOOL NONPROFIT and its agents will necessarily involve the use of natural materials and other props that may cause injury to your child if handled inappropriately by your child or by another child, and participation in any program provided by EARTHKIN NATURE SCHOOL NONPROFIT necessarily involves risks such as, but not limited to, bodily injury, death, or property damage which might result from the use of equipment or facilities, from the activity itself, from the acts of others or animals, or from the unavailability of emergency or emergency medical care.

		**ASSUMPTION OF ALL RISKS:** Understanding the above risks factors, the undersigned recognizes and assumes all risks that arise out of their child's participation and presence at EARTHKIN NATURE SCHOOL NONPROFIT facilities, functions, or other forums and specifically, but not limited to, injury or death from the use of any of EARTHKIN NATURE SCHOOL NONPROFIT'S equipment, use of its facilities, from the activity itself, the act of others or animals, or the unavailability of emergency care, including but not limited to, those risk factors described above.

		**RELEASE:** The undersigned releases EARTHKIN NATURE SCHOOL NONPROFIT, its agents, employees, or volunteers, as well as all heirs, executors, administrators and assigns and agrees not to sue them on account of or in conjunction with any claims, causes of action, injuries, damage, cost of expenses arising out of the activities referenced herein, including those claims based on death, bodily injury, or property damage whether or not caused by the acts, omissions or other fault of the parties being released.

		**WAIVER:** The undersigned waives the protection afforded by any statute or law in any jurisdiction in the State of Virginia which purpose, substance, and/or effect is to provide that a general release shall not extend to claims, material or otherwise which the person giving the release does not know of or suspect at the time of executing the release. This means, in part, that the undersigned is releasing unknown future claims.

		I, as the parent or legal guardian of the child named above, hereby waive, release, and shall hold harmless EARTHKIN NATURE SCHOOL NONPROFIT, Mrs. Sydney Gary, any employee, agent, or volunteer for EARTHKIN NATURE SCHOOL NONPROFIT, and any other parent, teacher, helper, child or adult participating in a EARTHKIN NATURE SCHOOL NONPROFIT program, from any injury to me, my family members or my child, or loss of property or other damage resulting from my or my child's participation in any EARTHKIN NATURE SCHOOL NONPROFIT program, activity, service or event. Similarly, I specifically waive any claim, be it legal, equitable, or administrative in any federal, state, or local forum against EARTHKIN NATURE SCHOOL NONPROFIT, Mrs. Gary, or any other parent, teacher, helper, or other child or adult participating in an EARTHKIN NATURE SCHOOL NONPROFIT program, activity, service or event.

		By signing below, I confirm that I understand and agree to the Family Agreement and the Waiver and Release.

		[[signature]]
	TEXT

	HEALTH_MEDICAL_CARE = <<~TEXT
		# Health and Medical Care Form

		This form helps us keep your child safe, supported, and well while in our care. Please complete every section thoroughly. All information will be kept confidential and used only by staff for emergency or health-related purposes.

		## Child Information

		**Full Name:** [[text:child_full_name|Child's full name]]
		**Date of Birth:** [[text:date_of_birth|Date of birth]]
		**Preferred Name:** [[text:preferred_name|Preferred name]]
		**Home Address:** [[text:home_address|Home address]]
		**Parent/Guardian Name:** [[text:parent_name|Parent/guardian name]]
		**Phone (Primary):** [[text:primary_phone|Primary phone]]
		**Email:** [[text:email|Email]]

		## Emergency Medical Authorization

		In the event of an emergency where I cannot be reached, I authorize Earthkin Nature School staff to obtain emergency medical care for my child, including transportation by ambulance and treatment at a hospital or urgent care center.

		## Health & Medical Information

		**Primary Care Provider:** [[text:pcp_name|Provider name]] **Phone:** [[text:pcp_phone|Provider phone]]
		**Insurance Provider:** [[text:insurance_provider|Insurance provider]] **Policy # (optional):** [[text:insurance_policy|Policy number]]

		**Does your child have any of the following?**

		[[checkbox:asthma|Asthma]]
		[[checkbox:allergies|Allergies (food, insect, environmental)]]
		[[checkbox:eczema|Eczema or skin sensitivities]]
		[[checkbox:seizures|Seizures]]
		[[checkbox:diabetes|Diabetes]]
		[[checkbox:other_condition|Other ongoing medical condition(s)]]

		If any are checked, please describe:
		[[textarea:conditions_description|Description of checked conditions]]

		**Allergies — please list all known allergies:**
		[[textarea:allergies_list|Known allergies]]
		**Reaction type:** [[text:allergy_reaction|Reaction type]]
		**Treatment (e.g., EpiPen, antihistamine):** [[text:allergy_treatment|Treatment]]

		## Medications

		**Does your child take any medications regularly?**

		[[checkbox:takes_medications|Yes, my child takes medication regularly]]

		If yes, list each medication's name, dose, time(s) given, and purpose:
		[[textarea:medications_list|Medications (name, dose, times, purpose)]]

		**Will any medication need to be administered during program hours?**

		[[checkbox:meds_during_program|Yes — medication is needed during program hours]]

		If yes, please also complete the Medication Administration Form and provide medication in its original container with your child's name and dosage instructions clearly labeled.

		## Outdoor & Environmental Considerations

		We spend 100% of our time outdoors in all types of weather. Please let us know if your child has any environmental sensitivities (e.g., to pollen, sun exposure, insect bites, cold, heat, etc.):
		[[textarea:environmental_sensitivities|Environmental sensitivities]]

		**Does your child require sunscreen, bug repellent, or other topical applications?**

		[[checkbox:needs_topicals|Yes — sunscreen, bug repellent, or other topicals needed]]

		If yes, please specify brand, preferences, or guidance: [[text:topicals_guidance|Brand/preferences/guidance]]

		## Social & Emotional Health

		Are there any strategies, comfort items, or routines that help your child feel safe and supported when upset, tired, or in a new environment?
		[[textarea:comfort_strategies|Strategies, comfort items, or routines]]

		## Parental Acknowledgment

		I understand that the staff of Earthkin Nature School are trained in basic first aid and CPR. I give permission for staff to provide minor first aid (e.g., cleaning scrapes, applying bandages, removing splinters) as needed.

		### Optional: Holistic/Family Health Notes

		If your family follows particular health practices or preferences (e.g., herbal remedies, dietary choices, spiritual considerations), please share any information that will help us honor your child's wellbeing holistically:
		[[textarea:holistic_notes|Holistic/family health notes]]

		**Thank you for taking the time to complete this form.** Your child's safety and wellbeing are our top priority — and by understanding their individual needs, we can ensure they thrive in nature each day.

		[[signature]]
	TEXT

	MEDICATION_ADMINISTRATION = <<~TEXT
		# Medication Administration Form

		This form must be completed for each medication your child needs while in our care. All medications must be in their original, labeled containers and given directly to staff. Medications are stored securely and administered according to the instructions below.

		## Child Information

		**Child's Full Name:** [[text:child_full_name|Child's full name]]
		**Date of Birth:** [[text:date_of_birth|Date of birth]]
		**Program:** 2026–2027 Nature Preschool

		## Medication Information

		**Medication Name:** [[text:medication_name|Medication name]]
		**Dosage (Amount):** [[text:dosage|Dosage]]

		**Route (how it's given):**

		[[checkbox:route_mouth|By mouth]]
		[[checkbox:route_topical|Topical]]
		[[checkbox:route_inhaled|Inhaled]]
		[[checkbox:route_other|Other:]] [[text:route_other_detail|Other route]]

		**Reason for Medication:** [[text:reason|Reason for medication]]
		**Time(s) to be Administered:** [[text:times|Times to administer]]
		**Start Date:** [[text:start_date|Start date]] **End Date:** [[text:end_date|End date]]

		**Special Instructions (e.g., take with food, shake well, storage needs):**
		[[textarea:special_instructions|Special instructions]]

		## Possible Side Effects or Reactions

		**Common or expected effects:** [[text:common_effects|Common or expected effects]]
		**Adverse reactions requiring medical attention:** [[text:adverse_reactions|Adverse reactions]]
		**Action to take if reaction occurs:** [[text:reaction_action|Action to take]]

		## Parent/Guardian Authorization

		I authorize Earthkin Nature School staff to administer the medication described above as instructed. I understand:

		- Medication will only be given according to these written directions.
		- All medications must be provided in their original containers, clearly labeled with my child's name.
		- I will notify staff immediately of any changes to this medication or dosage.

		**Phone:** [[text:parent_phone|Parent/guardian phone]]

		## Physician Information

		**Prescribing Physician:** [[text:physician_name|Physician name]]
		**Phone:** [[text:physician_phone|Physician phone]]
		**Office Address:** [[text:physician_address|Office address]]

		[[checkbox:is_prescribed|This is a prescribed medication]]
		[[checkbox:is_otc|This is an over-the-counter medication (administered with parent consent)]]

		**At Earthkin Nature School, we approach each child's health with care and mindfulness. Thank you for your partnership in supporting your child's wellbeing.**

		[[signature]]
	TEXT

	PARENT_GUARDIAN_CONTACT = <<~TEXT
		# Parent/Guardian Contact Form

		**Child's Full Name:** [[text:child_full_name|Child's full name]]
		**Date of Birth:** [[text:date_of_birth|Date of birth]]
		**Program:** 2026–2027 Nature Preschool

		## Parent/Guardian 1

		**Name:** [[text:p1_name|Name]]
		**Relationship to Child:** [[text:p1_relationship|Relationship]]
		**Primary Phone:** [[text:p1_phone|Primary phone]]
		**Secondary Phone (if applicable):** [[text:p1_phone2|Secondary phone]]
		**Email Address:** [[text:p1_email|Email]]
		**Home Address:** [[text:p1_address|Home address]]
		**Occupation/Workplace (optional):** [[text:p1_occupation|Occupation/workplace]]

		## Parent/Guardian 2

		**Name:** [[text:p2_name|Name]]
		**Relationship to Child:** [[text:p2_relationship|Relationship]]
		**Primary Phone:** [[text:p2_phone|Primary phone]]
		**Secondary Phone (if applicable):** [[text:p2_phone2|Secondary phone]]
		**Email Address:** [[text:p2_email|Email]]
		**Home Address (if different):** [[text:p2_address|Home address]]
		**Occupation/Workplace (optional):** [[text:p2_occupation|Occupation/workplace]]

		## Emergency Contacts (other than parents/guardians)

		These individuals may be contacted in case of emergency if parents/guardians are unavailable.

		**Contact 1 — Name:** [[text:ec1_name|Name]] **Relationship:** [[text:ec1_relationship|Relationship]] **Phone:** [[text:ec1_phone|Phone]]
		**Contact 2 — Name:** [[text:ec2_name|Name]] **Relationship:** [[text:ec2_relationship|Relationship]] **Phone:** [[text:ec2_phone|Phone]]

		## Authorized Pick-Up Persons

		List anyone other than parents/guardians who is permitted to pick up your child.

		**Person 1 — Name:** [[text:pu1_name|Name]] **Relationship:** [[text:pu1_relationship|Relationship]] **Phone:** [[text:pu1_phone|Phone]]
		**Person 2 — Name:** [[text:pu2_name|Name]] **Relationship:** [[text:pu2_relationship|Relationship]] **Phone:** [[text:pu2_phone|Phone]]
		**Person 3 — Name:** [[text:pu3_name|Name]] **Relationship:** [[text:pu3_relationship|Relationship]] **Phone:** [[text:pu3_phone|Phone]]

		## Communication Preferences

		Please check all that apply:

		[[checkbox:comm_text|Text Message]]
		[[checkbox:comm_email|Email]]
		[[checkbox:comm_phone|Phone Call]]
		[[checkbox:comm_other|Other:]] [[text:comm_other_detail|Other communication preference]]

		**Preferred Parent/Guardian for Primary Contact:** [[text:primary_contact|Preferred primary contact]]

		## Family Notes or Special Considerations

		Anything you'd like our staff to know — cultural traditions, family dynamics, or preferred communication styles:
		[[textarea:family_notes|Family notes or special considerations]]

		## Parent/Guardian Signature

		I certify that the information above is accurate and will notify Earthkin Nature School of any changes.

		[[signature]]
	TEXT

	FORM_BODIES = {
		'family_agreement' => FAMILY_AGREEMENT,
		'health_medical_care' => HEALTH_MEDICAL_CARE,
		'medication_administration' => MEDICATION_ADMINISTRATION,
		'parent_guardian_contact' => PARENT_GUARDIAN_CONTACT
	}.freeze
end
