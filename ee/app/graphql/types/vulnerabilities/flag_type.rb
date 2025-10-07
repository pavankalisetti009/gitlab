# frozen_string_literal: true

module Types
  module Vulnerabilities
    class FlagType < BaseObject
      graphql_name 'VulnerabilityFlag'
      description 'Represents a flag result for a vulnerability'

      authorize :read_vulnerability

      field :id, GraphQL::Types::ID, null: false,
        description: 'ID of the false positive detection.'

      field :status, Types::Vulnerabilities::Flags::FalsePositiveDetectionStatusEnum, null: true,
        experiment: { milestone: '18.5' },
        description: 'Status of the false positive detection.'

      field :confidence_score, GraphQL::Types::Float, null: true,
        experiment: { milestone: '18.5' },
        description: 'Confidence score of the detection (0.0 to 1.0).'

      field :origin, GraphQL::Types::String, null: true,
        description: 'Origin of service that raising the flag on the vulnerability.'

      field :description, GraphQL::Types::String, null: true,
        description: 'Reasoning for the raising of the flag on the vulnerability.'

      field :created_at, Types::TimeType, null: false,
        description: 'Timestamp when the detection was created.'

      field :updated_at, Types::TimeType, null: false,
        description: 'Timestamp when the detection was last updated.'
    end
  end
end
