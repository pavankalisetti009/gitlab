# frozen_string_literal: true

FactoryBot.define do
  factory :duo_chat_event, class: '::Ai::DuoChatEvent' do
    event { 'request_duo_chat_response' }
    user { build_stubbed(:user, :with_namespace) }
    payload { {} }
  end
end
