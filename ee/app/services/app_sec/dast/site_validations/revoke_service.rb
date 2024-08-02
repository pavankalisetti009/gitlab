# frozen_string_literal: true

module AppSec
  module Dast
    module SiteValidations
      class RevokeService < BaseContainerService
        MissingParamError = Class.new(StandardError)

        def execute
          return ServiceResponse.error(message: 'Insufficient permissions') unless allowed?

          finder = DastSiteValidationsFinder.new(
            project_id: container.id,
            url_base: url_base
          )

          result = ::Gitlab::Database.allow_cross_joins_across_databases(
            url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/474985'
          ) do
            finder.execute.delete_all
          end

          ServiceResponse.success(payload: { count: result })
        rescue MissingParamError => err
          ServiceResponse.error(message: err.message)
        end

        private

        def allowed?
          container.licensed_feature_available?(:security_on_demand_scans)
        end

        def url_base
          params[:url_base] || raise(MissingParamError, 'URL parameter used to search for validations is missing')
        end
      end
    end
  end
end
