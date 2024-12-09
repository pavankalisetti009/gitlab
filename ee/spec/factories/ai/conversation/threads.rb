# frozen_string_literal: true

FactoryBot.define do
  factory :ai_conversation_thread, class: '::Ai::Conversation::Thread' do
    conversation_type { :duo_chat }
    last_updated_at { Time.zone.now }
    organization { association(:organization, :default) }
    user
  end
end
