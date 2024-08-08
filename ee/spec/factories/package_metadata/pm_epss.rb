# frozen_string_literal: true

FactoryBot.define do
  factory :pm_epss, class: 'PackageMetadata::Epss' do
    cve { "CVE-1234-12345" }
    score { 12.34 }
  end
end
