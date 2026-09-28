namespace :billing do
  desc "Report (or with APPLY=1, fix) locked-in schedules billed at the standard rate despite a custom tuition"
  task reprice_custom_tuition: :environment do
    apply = ENV["APPLY"] == "1"
    puts apply ? "Re-pricing schedules..." : "Dry run (set APPLY=1 to fix):"

    affected = 0
    EnrollmentApplication.where.not(custom_tuition_amount: nil).find_each do |application|
      epp = application.program_enrollment&.enrollment_payment_plan
      next unless epp

      scheduled = epp.installments.sum { |i| i["amount"].to_d }
      next if scheduled == application.custom_tuition_amount.to_d

      affected += 1
      unpaid = epp.installments.count { |i| i["status"] != "completed" }
      puts "  #{application.full_child_name} (#{application.program.name}): custom tuition " \
           "$#{application.custom_tuition_amount}, scheduled $#{scheduled.to_f}, #{unpaid} unpaid installments"
      next unless apply

      epp.reprice!(tuition: application.custom_tuition_amount)
      puts "    now: #{epp.reload.installments.map { |i| i['amount'] }.join(', ')}"
    end

    puts "#{affected} affected"
  end
end
