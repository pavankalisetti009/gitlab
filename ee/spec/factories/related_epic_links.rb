# frozen_string_literal: true

FactoryBot.define do
  factory :related_epic_link, class: 'Epic::RelatedEpicLink' do
    source factory: :epic
    target factory: :epic

    trait :with_related_work_item_link do
      related_work_item_link do
        association(:work_item_link, source: source.work_item, target: target.work_item)
      end
    end
  end
end
