# frozen_string_literal: true

FactoryBot.define do
  factory :analyzer_project_status, class: 'Security::AnalyzerProjectStatus' do
    project
    build factory: [:ci_build, :success]
    status { :success }
    analyzer_type { :sast }
    last_call { Time.current }

    after(:build) do |status, _|
      status.traversal_ids = status.project&.namespace&.traversal_ids
    end
  end
end
