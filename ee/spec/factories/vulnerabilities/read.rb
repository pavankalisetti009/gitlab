# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_read, class: 'Vulnerabilities::Read' do
    vulnerability factory: :vulnerability
    project factory: :project
    scanner factory: :vulnerabilities_scanner
    report_type { :sast }
    severity { :high }
    state { :detected }
    uuid { SecureRandom.uuid }
    traits_for_enum :dismissal_reason, Vulnerabilities::DismissalReasonEnum.values.keys

    after(:build) do |vulnerability_read, _|
      vulnerability_read.archived = vulnerability_read.project&.archived
      vulnerability_read.traversal_ids = vulnerability_read.project&.namespace&.traversal_ids
    end
  end

  trait :with_remediations do
    has_remediations { true }
  end

  trait :with_owasp_top_10 do
    transient do
      owasp_top_10 { "A1:2017-Injection" }
    end

    after(:build) do |vulnerability_read, evaluator|
      vulnerability_read.owasp_top_10 = evaluator.owasp_top_10
    end
  end
end
