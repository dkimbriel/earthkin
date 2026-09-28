require 'rails_helper'
require 'rake'

RSpec.describe 'billing:reprice_custom_tuition' do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.empty? }

  let(:task) { Rake::Task['billing:reprice_custom_tuition'] }
  let(:plan) { create(:payment_plan, :monthly) }
  let(:application) { create(:enrollment_application, program: plan.program, custom_tuition_amount: 2500) }
  let!(:epp) do
    enrollment = create(:program_enrollment, program: plan.program, enrollment_application: application)
    create(:enrollment_payment_plan, :with_monthly_plan, program_enrollment: enrollment, payment_plan: plan, total_amount: 2500)
  end

  after do
    task.reenable
    ENV.delete('APPLY')
  end

  it 'only reports by default' do
    expect { task.invoke }.to output(/1 affected/).to_stdout
    expect(epp.reload.installments.map { |i| i['amount'] }).to all(eq(280))
  end

  it 're-prices the unpaid installments with APPLY=1' do
    ENV['APPLY'] = '1'
    expect { task.invoke }.to output(/1 affected/).to_stdout
    expect(epp.reload.installments.map { |i| i['amount'] }).to all(eq(250.0))
  end

  it 'skips schedules that already match the custom tuition' do
    epp.reprice!(tuition: 2500)
    expect { task.invoke }.to output(/0 affected/).to_stdout
  end
end
