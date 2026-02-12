# frozen_string_literal: true

FactoryBot.modify do
  factory :helm_metadata_cache do
    with_file

    trait(:verification_succeeded) do
      verification_checksum { 'abc' }
      verification_state { Packages::Helm::MetadataCache.verification_state_value(:verification_succeeded) }
    end

    trait(:verification_failed) do
      verification_failure { 'Could not calculate the checksum' }
      verification_state { Packages::Helm::MetadataCache.verification_state_value(:verification_failed) }

      #
      # Geo::VerifiableReplicator#after_verifiable_update tries to verify
      # the replicable async and marks it as verification started when the
      # model record is created/updated.
      #
      after(:create) do |instance, evaluator|
        instance.verification_failure = evaluator.verification_failure
        instance.verification_failed!
      end
    end
  end
end
