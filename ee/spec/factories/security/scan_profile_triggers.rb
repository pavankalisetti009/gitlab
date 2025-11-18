# frozen_string_literal: true

FactoryBot.define do
  factory :security_scan_profile_trigger, class: 'Security::ScanProfileTrigger' do
    scan_profile { association(:security_scan_profile) }
    namespace { association :group }
    trigger_type { :default_branch_pipeline }
  end
end
