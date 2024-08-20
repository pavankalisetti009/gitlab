# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_namespace_historical_statistics, class: 'Vulnerabilities::NamespaceHistoricalStatistic' do
    letter_grade { 'a' }
    date { Date.current }
    traversal_ids { [12, 13, 14] }
  end
end
