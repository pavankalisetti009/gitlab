# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_checkpoint, class: 'Ai::DuoWorkflows::Checkpoint' do
    workflow { association(:duo_workflows_workflow) }
    checkpoint { { key: 'value' } }
    metadata { { metadata_key: 'metadata value' } }
    thread_ts { Gitlab::Utils.uuid_v7 }
    parent_ts { Gitlab::Utils.uuid_v7 }
    project { association(:project) }
  end
end
