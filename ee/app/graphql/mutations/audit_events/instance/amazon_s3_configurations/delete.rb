# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Instance
      module AmazonS3Configurations
        class Delete < Base
          graphql_name 'AuditEventsInstanceAmazonS3ConfigurationDelete'

          argument :id, ::Types::GlobalIDType[::AuditEvents::Instance::AmazonS3Configuration],
            required: true,
            description: 'ID of the instance-level Amazon S3 configuration to delete.'

          def resolve(id:)
            config = authorized_find!(id: id)
            paired_destination = config.stream_destination

            if config.destroy
              audit(config, action: :deleted)

              paired_destination&.destroy
            end

            { errors: Array(config.errors) }
          end
        end
      end
    end
  end
end
