# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      module DesiredConfig
        module PoststartCommandsHelper
          include RemoteDevelopmentConstants

          # @param [Hash] processed_devfile
          # @return [String]
          def extract_main_component_name(processed_devfile:)
            components = processed_devfile.fetch(:components)

            main_component = components.find do |component|
              component.dig(:attributes, MAIN_COMPONENT_INDICATOR_ATTRIBUTE.to_sym)
            end

            main_component.fetch(:name)
          end
        end
      end
    end
  end
end
