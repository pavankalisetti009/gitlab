# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_collection, class: 'Ai::ActiveContext::Collection' do
    name { ActiveContextHelpers.code_collection_name }
    association :connection, factory: [:ai_active_context_connection, :elasticsearch]

    trait :code_embeddings_with_versions do
      collection_class { "Ai::ActiveContext::Collections::Code" }

      # The attributes for indexing_embedding_versions are defined in
      # Ai::ActiveContext::Collections::Code::MODEL
      indexing_embedding_versions { [1] }
    end
  end
end
