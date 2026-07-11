class MarkRequiredFormFields < ActiveRecord::Migration[7.0]
	# Marks required fields in the four seeded enrollment forms: a trailing *
	# on a field label makes it required, and [[require-one:a,b|Message]] lines
	# require at least one checkbox of a group. Edits are surgical string
	# replacements, so admin changes elsewhere in a form are preserved; a
	# replacement that finds nothing (because the admin rewrote that line)
	# is skipped silently.

	class MigrationFormTemplate < ActiveRecord::Base
		self.table_name = 'form_templates'
	end

	EDITS = {
		'family_agreement' => [
			["[[text:child_full_name|Child's full name]]", "[[text:child_full_name|Child's full name*]]"],
			["[[checkbox:plan_monthly|Option 4: Monthly Payments — 10 payments of $280 due the first of each month beginning Aug 1 through May 1]]",
			 "[[checkbox:plan_monthly|Option 4: Monthly Payments — 10 payments of $280 due the first of each month beginning Aug 1 through May 1]]\n[[require-one:plan_full,plan_semester,plan_quarterly,plan_monthly|Please choose one payment plan option]]"],
			['[[checkbox:donation_none|I am unable to make a donation at this time]]',
			 "[[checkbox:donation_none|I am unable to make a donation at this time]]\n[[require-one:donation_50,donation_100,donation_150,donation_250,donation_500,donation_other,donation_none|Please choose a donation option (selecting \"unable at this time\" is perfectly fine)]]"],
			['[[checkbox:media_no_permission|I DO NOT GIVE permission for Earthkin Nature School to use any photographs, videos, or recordings of my child for any purpose.]]',
			 "[[checkbox:media_no_permission|I DO NOT GIVE permission for Earthkin Nature School to use any photographs, videos, or recordings of my child for any purpose.]]\n[[require-one:media_permission,media_no_permission|Please choose a media permission option]]"],
			['[[checkbox:agree_all|I confirm I have read, understand, and agree to all above]]',
			 "[[checkbox:agree_all|I confirm I have read, understand, and agree to all above]]\n[[require-one:agree_all|Please confirm you have read and agree to the sections above]]"]
		],
		'health_medical_care' => [
			["[[text:child_full_name|Child's full name]]", "[[text:child_full_name|Child's full name*]]"],
			['[[text:date_of_birth|Date of birth]]', '[[text:date_of_birth|Date of birth*]]'],
			['[[text:home_address|Home address]]', '[[text:home_address|Home address*]]'],
			['[[text:parent_name|Parent/guardian name]]', '[[text:parent_name|Parent/guardian name*]]'],
			['[[text:primary_phone|Primary phone]]', '[[text:primary_phone|Primary phone*]]'],
			['[[text:email|Email]]', '[[text:email|Email*]]'],
			['[[text:pcp_name|Provider name]]', '[[text:pcp_name|Provider name*]]'],
			['[[text:pcp_phone|Provider phone]]', '[[text:pcp_phone|Provider phone*]]']
		],
		'medication_administration' => [
			["[[text:child_full_name|Child's full name]]", "[[text:child_full_name|Child's full name*]]"],
			['[[text:date_of_birth|Date of birth]]', '[[text:date_of_birth|Date of birth*]]'],
			['[[text:medication_name|Medication name]]', '[[text:medication_name|Medication name*]]'],
			['[[text:dosage|Dosage]]', '[[text:dosage|Dosage*]]'],
			['[[text:reason|Reason for medication]]', '[[text:reason|Reason for medication*]]'],
			['[[text:times|Times to administer]]', '[[text:times|Times to administer*]]'],
			['[[text:start_date|Start date]]', '[[text:start_date|Start date*]]'],
			['[[text:parent_phone|Parent/guardian phone]]', '[[text:parent_phone|Parent/guardian phone*]]'],
			['[[checkbox:route_other|Other:]] [[text:route_other_detail|Other route]]',
			 "[[checkbox:route_other|Other:]] [[text:route_other_detail|Other route]]\n[[require-one:route_mouth,route_topical,route_inhaled,route_other|Please choose how the medication is given]]"],
			['[[checkbox:is_otc|This is an over-the-counter medication (administered with parent consent)]]',
			 "[[checkbox:is_otc|This is an over-the-counter medication (administered with parent consent)]]\n[[require-one:is_prescribed,is_otc|Please indicate whether this is a prescribed or over-the-counter medication]]"]
		],
		'parent_guardian_contact' => [
			["[[text:child_full_name|Child's full name]]", "[[text:child_full_name|Child's full name*]]"],
			['[[text:date_of_birth|Date of birth]]', '[[text:date_of_birth|Date of birth*]]'],
			['[[text:p1_name|Name]]', '[[text:p1_name|Name*]]'],
			['[[text:p1_relationship|Relationship]]', '[[text:p1_relationship|Relationship*]]'],
			['[[text:p1_phone|Primary phone]]', '[[text:p1_phone|Primary phone*]]'],
			['[[text:p1_email|Email]]', '[[text:p1_email|Email*]]'],
			['[[text:p1_address|Home address]]', '[[text:p1_address|Home address*]]'],
			['[[text:ec1_name|Name]]', '[[text:ec1_name|Name*]]'],
			['[[text:ec1_relationship|Relationship]]', '[[text:ec1_relationship|Relationship*]]'],
			['[[text:ec1_phone|Phone]]', '[[text:ec1_phone|Phone*]]'],
			['[[text:primary_contact|Preferred primary contact]]', '[[text:primary_contact|Preferred primary contact*]]'],
			['[[checkbox:comm_other|Other:]] [[text:comm_other_detail|Other communication preference]]',
			 "[[checkbox:comm_other|Other:]] [[text:comm_other_detail|Other communication preference]]\n[[require-one:comm_text,comm_email,comm_phone,comm_other|Please choose at least one communication preference]]"]
		]
	}.freeze

	def up
		EDITS.each do |key, replacements|
			template = MigrationFormTemplate.find_by(key: key)
			next unless template

			body = template.body.dup
			replacements.each { |old, new| body.sub!(old, new) }
			template.update!(body: body) if body != template.body
		end
	end

	def down
		# Content edit — nothing sensible to revert to.
	end
end
