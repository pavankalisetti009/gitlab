# frozen_string_literal: true

module Repositories
  module PullMirrors
    class UpdateService < ::BaseService
      def execute
        return ServiceResponse.error(message: _('Access Denied')) unless allowed?

        if project.update(allowed_attributes.merge(mirror_user_id: current_user.id))
          project.import_state.force_import_job! if project.mirror?

          ServiceResponse.success(payload: { project: project })
        else
          ServiceResponse.error(message: project.errors)
        end
      end

      private

      def allowed_attributes
        Repositories::PullMirrors::Attributes.new(params).allowed
      end

      def allowed?
        Ability.allowed?(current_user, :admin_remote_mirror, project)
      end
    end
  end
end
