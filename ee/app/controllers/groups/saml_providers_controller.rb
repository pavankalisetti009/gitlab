# frozen_string_literal: true
require_relative '../concerns/saml_authorization'

class Groups::SamlProvidersController < Groups::ApplicationController
  include SamlAuthorization
  include SafeFormatHelper

  before_action :require_top_level_group
  before_action :authorize_manage_saml!
  before_action :check_group_saml_available!
  before_action :check_group_saml_configured
  before_action :check_microsoft_group_sync_available, only: [:update_microsoft_application]
  before_action :find_or_initialize_microsoft_application, only: [:show]

  feature_category :system_access

  def show
    @saml_provider = @group.saml_provider || @group.build_saml_provider
    @saml_response_check = load_test_response if @saml_provider.persisted?

    scim_token = if Feature.enabled?(:separate_group_scim_table, @group)
                   GroupScimAuthAccessToken.find_by_group_id(@group.id)
                 else
                   ScimOauthAccessToken.find_by_group_id(@group.id)
                 end

    @scim_token_url = scim_token.as_entity_json[:scim_api_url] if scim_token
  end

  def create
    create_service = GroupSaml::SamlProvider::CreateService.new(current_user, @group, params: saml_provider_params)

    create_service.execute

    @saml_provider = create_service.saml_provider

    render :show
  end

  def update
    @saml_provider = @group.saml_provider

    GroupSaml::SamlProvider::UpdateService.new(current_user, @saml_provider, params: saml_provider_params).execute

    render :show
  end

  def update_microsoft_application
    params = microsoft_application_params.dup
    params.delete(:client_secret) if params[:client_secret].blank?

    result = update_microsoft_application_model(params)

    if result[:status]
      flash[:notice] = s_('Microsoft|Microsoft Azure integration settings were successfully updated.')
    else
      flash[:alert] = safe_format(
        s_('Microsoft|Microsoft Azure integration settings failed to save. %{errors}'),
        errors: result[:errors].to_sentence
      )
    end

    redirect_to group_saml_providers_path(group)
  end

  private

  def load_test_response
    test_response = Gitlab::Auth::GroupSaml::ResponseStore.new(session.id).get_raw
    return if test_response.blank?

    Gitlab::Auth::GroupSaml::ResponseCheck.for_group(group: @group, raw_response: test_response, user: current_user)
  end

  def saml_provider_params
    allowed_params = [
      :sso_url,
      :certificate_fingerprint,
      :enabled,
      :disable_password_authentication_for_enterprise_users,
      :enforced_sso,
      :default_membership_role,
      :git_check_enforced
    ]
    allowed_params << :member_role_id if group.custom_roles_enabled?

    if Feature.enabled?(:group_managed_accounts, group)
      allowed_params += [:enforced_group_managed_accounts, :prohibited_outer_forks]
    end

    params.require(:saml_provider).permit(allowed_params)
  end

  # rubocop:disable CodeReuse/ActiveRecord -- splitting out legacy code
  def find_or_initialize_microsoft_application
    is_enabled = Feature.enabled?(:group_microsoft_applications_table, @group)

    @microsoft_application = if is_enabled
                               ::SystemAccess::GroupMicrosoftApplication.find_or_initialize_by(
                                 group: @group
                               )
                             else
                               ::SystemAccess::MicrosoftApplication.find_or_initialize_by(
                                 namespace: @group
                               )
                             end
  end

  def update_microsoft_application_model(params)
    group_app = ::SystemAccess::GroupMicrosoftApplication.find_or_initialize_by(
      group: @group
    )
    legacy_app = ::SystemAccess::MicrosoftApplication.find_or_initialize_by(
      namespace: @group
    )

    group_app_result = nil
    legacy_app_result = nil

    ::SystemAccess::GroupMicrosoftApplication.transaction do
      group_app_result = group_app.update(params)
      legacy_app_result = legacy_app.update(params)

      raise ActiveRecord::Rollback unless group_app_result && legacy_app_result
    end

    errors = group_app.errors.full_messages + legacy_app.errors.full_messages

    {
      status: group_app_result && legacy_app_result,
      errors: errors.uniq
    }
  end
  # rubocop:enable CodeReuse/ActiveRecord

  def microsoft_application_params
    fields = %i[enabled tenant_xid client_xid client_secret login_endpoint graph_endpoint]

    if Feature.enabled?(:group_microsoft_applications_table, @group)
      params.require(:system_access_group_microsoft_application).permit(*fields)
    else
      params.require(:system_access_microsoft_application).permit(*fields)
    end
  end

  def check_microsoft_group_sync_available
    render_404 unless @group.saml_provider&.enabled?
  end
end
