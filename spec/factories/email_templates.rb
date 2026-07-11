FactoryBot.define do
  factory :email_template do
    name { 'My Template' }
    subject { 'Hello {{parent_name}}' }
    body { "Hi {{parent_name}},\n\nThis is a template." }
  end
end
