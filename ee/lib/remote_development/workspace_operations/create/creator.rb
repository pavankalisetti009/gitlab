# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class Creator
        include CreateConstants
        include Messages

        RANDOM_STRING_LENGTH = 6

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.create(context)
          model_errors = nil

          updated_value = ApplicationRecord.transaction do
            initial_result = Gitlab::Fp::Result.ok(context)

            result =
              initial_result
                .map(CreatorBootstrapper.method(:bootstrap))
                .and_then(PersonalAccessTokenCreator.method(:create))
                .and_then(WorkspaceCreator.method(:create))
                .and_then(WorkspaceVariablesCreator.method(:create))

            case result
            in { err: PersonalAccessTokenModelCreateFailed |
              WorkspaceModelCreateFailed |
              WorkspaceVariablesModelCreateFailed => message
            }
              model_errors = message.content[:errors]
              raise ActiveRecord::Rollback
            else
              result.unwrap
            end
          end

          return Gitlab::Fp::Result.err(WorkspaceCreateFailed.new({ errors: model_errors })) if model_errors.present?

          Gitlab::Fp::Result.ok(WorkspaceCreateSuccessful.new(updated_value))
        end
      end
    end
  end
end
