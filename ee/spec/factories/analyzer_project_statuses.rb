# frozen_string_literal: true

FactoryBot.define do
  factory :analyzer_project_status, class: 'Security::AnalyzerProjectStatus' do
    project
    status { :not_configured }
    analyzer_type { :sast }
    last_call { Time.current }

    after(:build) do |status, _|
      status.traversal_ids = status.project&.namespace&.traversal_ids
    end
  end
end
