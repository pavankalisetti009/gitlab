# frozen_string_literal: true

module CloudConnector
  module SelfManaged
    class AccessDataReader
      include ::CloudConnector::Utils
      include Gitlab::Utils::StrongMemoize

      def read_available_services
        service_descriptors = access_record_data&.[]('available_services') || []
        service_descriptors.map { |access_data| build_available_service_data(access_data) }.index_by(&:name)
      end
      strong_memoize_attr :read_available_services

      private

      def access_record_data
        ::CloudConnector::Access.last&.data
      end

      def build_available_service_data(access_data)
        AvailableServiceData.new(
          access_data['name'].to_sym,
          parse_time(access_data["serviceStartTime"]),
          access_data["bundledWith"].to_a
        )
      end
    end
  end
end
