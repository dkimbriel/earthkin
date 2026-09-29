require 'rails_helper'

RSpec.describe AutopayCharger do
  let(:today) { Date.new(2026, 10, 24) }
  let(:family) { create(:family, stripe_customer_id: 'cus_1') }
  let!(:parent) { create(:parent, family: family, email: 'mom@example.com') }
  let(:child) { create(:child, family: family, first_name: 'Theo') }
  let(:enrollment) { create(:program_enrollment, child: child, status: 'confirmed') }
  let!(:plan) do
    create(:enrollment_payment_plan, program_enrollment: enrollment, total_amount: 546.69,
                                     installments: [
                                       { 'due_date' => '2026-09-24', 'amount' => 273.36, 'status' => 'pending', 'paid_at' => nil },
                                       { 'due_date' => '2026-10-24', 'amount' => 273.33, 'status' => 'pending', 'paid_at' => nil },
                                       { 'due_date' => '2026-11-24', 'amount' => 273.33, 'status' => 'pending', 'paid_at' => nil }
                                     ]).tap do |p|
      p.enable_autopay!(method: { id: 'pm_card', type: 'card', label: 'Visa ending 4242' }, enabled_by: 'mom@example.com')
      p.update!(autopay_enabled_at: Time.zone.local(2026, 10, 1))
    end
  end

  def intent(status, id: 'pi_1')
    double('Stripe::PaymentIntent', id: id, status: status,
                                    latest_charge: double('charge', receipt_url: 'https://pay.stripe.com/r/1'))
  end

  def invoice_for(index)
    plan.payments.find_by(installment_number: index + 1)
  end

  before { allow(AdminNotifier).to receive(:payment_completed) }

  it "charges the installment due today, but not one that fell due before autopay was on, or one in the future" do
    expect(Stripe::PaymentIntent).to receive(:create).once.with(
      hash_including(amount: 27_333, customer: 'cus_1', payment_method: 'pm_card', payment_method_types: ['card'],
                     off_session: true, confirm: true, metadata: hash_including(kind: 'autopay')),
      anything
    ).and_return(intent('succeeded'))

    results = described_class.run(date: today)

    expect(results[:charged]).to eq(1)
    expect(plan.reload.installments.map { |i| i['status'] }).to eq(%w[pending completed pending])
    expect(invoice_for(1)).to have_attributes(status: 'completed', payment_method: 'stripe', autopay_attempts: 1,
                                              stripe_payment_intent_id: 'pi_1', stripe_receipt_url: 'https://pay.stripe.com/r/1')
    expect(invoice_for(0)).to be_nil
  end

  it 'uses one idempotency key per invoice and attempt' do
    plan
    expect(Stripe::PaymentIntent).to receive(:create) do |_params, opts|
      expect(opts[:idempotency_key]).to eq("autopay-#{invoice_for(1).id}-1")
      intent('succeeded')
    end

    described_class.run(date: today)
  end

  it 'leaves a bank payment pending while it processes, and does not charge it again' do
    plan.update!(autopay_method_type: 'us_bank_account', autopay_mandate_id: 'mandate_1')
    expect(Stripe::PaymentIntent).to receive(:create).once
                                                      .with(hash_including(payment_method_types: ['us_bank_account'], mandate: 'mandate_1'), anything)
                                                      .and_return(intent('processing', id: 'pi_bank'))

    expect(described_class.run(date: today)[:processing]).to eq(1)
    expect(invoice_for(1)).to have_attributes(status: 'pending', stripe_payment_intent_id: 'pi_bank', autopay_attempts: 1)

    described_class.run(date: today + 1)
  end

  it 'retries a declined card 3 days later, then emails a pay link and notifies admins' do
    plan
    decline = Stripe::CardError.new('Your card was declined.', nil, code: 'card_declined')
    allow(Stripe::PaymentIntent).to receive(:create).and_raise(decline)
    allow(AdminNotifier).to receive(:autopay_failed)

    expect(described_class.run(date: today)[:retrying]).to eq(1)
    expect(invoice_for(1)).to have_attributes(autopay_attempts: 1, autopay_retry_on: today + 3, autopay_error: 'Your card was declined.')

    expect(described_class.run(date: today + 1)).not_to include(:retrying, :failed)

    expect {
      expect(described_class.run(date: today + 3)[:failed]).to eq(1)
    }.to change { Email.where(email_type: 'autopay_failed').count }.by(1)
    expect(AdminNotifier).to have_received(:autopay_failed).with(invoice_for(1))
    expect(invoice_for(1)).to have_attributes(status: 'pending', autopay_attempts: 2, autopay_retry_on: nil)

    # Out of attempts: never charged again automatically.
    described_class.run(date: today + 10)
    expect(Stripe::PaymentIntent).to have_received(:create).twice
  end

  it "doesn't count our own errors as a failed attempt" do
    plan
    allow(Stripe::PaymentIntent).to receive(:create).and_raise(Stripe::InvalidRequestError.new('No such customer', 'customer'))

    expect(described_class.run(date: today)[:error]).to eq(1)
    expect(invoice_for(1).autopay_attempts).to eq(0)
    expect(Email.where(email_type: 'autopay_failed')).to be_empty
  end

  it 'skips installments already paid another way, and cancelled enrollments' do
    plan.mark_installment_paid!(1, create(:payment, program_enrollment: enrollment))
    expect(Stripe::PaymentIntent).not_to receive(:create)
    described_class.run(date: today)

    # November's installment would be due, but the enrollment was cancelled.
    enrollment.update!(status: 'cancelled')
    described_class.run(date: today + 31)
  end

  it 'charges nothing when autopay is off' do
    plan.disable_autopay!
    expect(Stripe::PaymentIntent).not_to receive(:create)
    described_class.run(date: today)
  end

  it 'only logs in a dry run' do
    plan
    expect(Stripe::PaymentIntent).not_to receive(:create)
    expect(described_class.run(date: today, dry_run: true)[:dry_run]).to eq(1)
  end
end
