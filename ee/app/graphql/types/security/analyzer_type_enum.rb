# frozen_string_literal: true

module Types
  module Security
    class AnalyzerTypeEnum < Types::BaseEnum
      graphql_name 'AnalyzerTypeEnum'
      description 'Enum for types of analyzers '

      Enums::Security.analyzer_types.each_key do |analyzer_type|
        value analyzer_type.to_s.upcase,
          value: analyzer_type.to_s,
          description: "#{analyzer_type.to_s.upcase.tr('_', ' ')} analyzer."
      end
    end
  end
end
