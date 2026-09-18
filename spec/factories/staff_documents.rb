FactoryBot.define do
  factory :staff_document do
    teacher
    title { 'Termination Letter' }
    employee_position { 'Lead Teacher' }
    body { "# Notice\n\nYour employment ends on September 16, 2026.\n\n[[signature]]\n" }
  end
end
