# frozen_string_literal: true

FactoryBot.define do
  factory :elastic_reindexing_task, class: 'Search::Elastic::ReindexingTask' do
    state { :initial }
    in_progress { true }

    trait :with_subtask do
      subtasks { [association(:elastic_reindexing_subtask)] }
    end
  end
end
