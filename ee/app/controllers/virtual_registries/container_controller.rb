# frozen_string_literal: true

module VirtualRegistries
  # TODO: Extract shared JWT authentication logic
  # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/578299
  class ContainerController < ::ApplicationController
    include Gitlab::Utils::StrongMemoize

    EMPTY_AUTH_RESULT = Gitlab::Auth::Result.new(nil, nil, nil, nil).freeze
    PERMITTED_PARAMS = %i[id image tag_or_digest sha].freeze

    delegate :actor, to: :@authentication_result, allow_nil: true
    alias_method :authenticated_user, :actor

    # We disable `authenticate_user!` since we perform auth using JWT token
    skip_before_action :authenticate_user!, raise: false

    before_action :skip_session
    before_action :ensure_feature_available!
    before_action :authenticate_user_from_jwt_token!
    before_action :ensure_user_has_access!

    feature_category :virtual_registry
    urgency :low

    def manifest
      render json: { message: 'Not implemented' }, status: :not_implemented
    end

    def blob
      render json: { message: 'Not implemented' }, status: :not_implemented
    end

    private

    def skip_session
      request.session_options[:skip] = true
    end

    def ensure_feature_available!
      render_404 unless registry && ::VirtualRegistries::Container.feature_enabled?(registry.group)
    end

    def registry
      ::VirtualRegistries::Container::Registry.find_by_id(permitted_params[:id])
    end
    strong_memoize_attr :registry

    def permitted_params
      params.permit(PERMITTED_PARAMS)
    end

    # JWT Authentication (duplicated from Groups::DependencyProxy::ApplicationController)
    def authenticate_user_from_jwt_token!
      authenticate_with_http_token do |token, _|
        @authentication_result = EMPTY_AUTH_RESULT

        user_or_token = ::DependencyProxy::AuthTokenService.user_or_token_from_jwt(token)

        case user_or_token
        when User
          set_auth_result(user_or_token, :user)
          sign_in(user_or_token) if can_sign_in?(user_or_token)
        when PersonalAccessToken
          set_auth_result(user_or_token.user, :personal_access_token)
          @personal_access_token = user_or_token
        when DeployToken
          set_auth_result(user_or_token, :deploy_token)
        end
      end

      request_bearer_token! unless authenticated_user
    end

    def set_auth_result(actor, type)
      @authentication_result = Gitlab::Auth::Result.new(actor, nil, type, [])
    end

    def can_sign_in?(user_or_token)
      return false if user_or_token.project_bot? || user_or_token.service_account?

      true
    end

    def request_bearer_token!
      response.headers['WWW-Authenticate'] = ::DependencyProxy::Registry.authenticate_header
      render plain: '', status: :unauthorized
    end

    def ensure_user_has_access!
      render_404 unless ::VirtualRegistries::Container.user_has_access?(registry.group, authenticated_user)
    end
  end
end
