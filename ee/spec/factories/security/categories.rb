# frozen_string_literal: true

FactoryBot.define do
  factory :security_category, class: 'Security::Category' do
    namespace { nil }
    editable_state { :locked }
    template_type { nil }
    multiple_selection { false }
    name { 'Test Category' }
    description { 'This is a test category' }
  end
end
