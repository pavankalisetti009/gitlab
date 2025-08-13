# frozen_string_literal: true

module EE
  module PersonalAccessTokensFinder # rubocop:disable Gitlab/BoundedContexts -- Original class in core is not in a bounded context
    extend ::Gitlab::Utils::Override

    override :by_owner_type
    def by_owner_type(tokens)
      case params[:owner_type]
      when 'service_account'
        if ::Feature.enabled?(:optimize_credentials_inventory, params[:group] || :instance)
          tokens.for_user_types(:service_account)
        else
          tokens.owner_is_service_account
        end
      else
        super
      end
    end
  end
end
