# frozen_string_literal: true

module EE
  module ProfilesController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    def join_early_access_program
      ::Users::JoinEarlyAccessProgramService.new(current_user).execute

      head(:ok)
    end
  end
end
