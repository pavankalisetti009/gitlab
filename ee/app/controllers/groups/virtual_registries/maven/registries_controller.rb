# frozen_string_literal: true

module Groups
  module VirtualRegistries
    module Maven
      class RegistriesController < Groups::VirtualRegistries::BaseController
        before_action :verify_read_virtual_registry!, only: [:index, :show]
        before_action :verify_create_virtual_registry!, only: [:new, :create]
        before_action :set_registry, only: [:show]

        before_action :push_ability, only: [:index]

        feature_category :virtual_registry
        urgency :low

        def index; end

        def new
          @maven_registry = ::VirtualRegistries::Packages::Maven::Registry.new
        end

        def create
          @maven_registry = ::VirtualRegistries::Packages::Maven::Registry.new(
            create_params.merge(group:)
          )

          if @maven_registry.save
            redirect_to group_virtual_registries_maven_registry_path(group, @maven_registry),
              notice: s_("VirtualRegistry|Maven virtual registry was created")
          else
            render :new
          end
        end

        def show; end

        private

        def push_ability
          push_frontend_ability(ability: :update_virtual_registry,
            resource: group.virtual_registry_policy_subject, user: current_user)
        end

        def set_registry
          @maven_registry = ::VirtualRegistries::Packages::Maven::Registry
            .find_by_id_and_group_id!(show_params[:id], group.id)
        end

        def show_params
          params.permit(:id)
        end

        def create_params
          params.require(:maven_registry).permit(:name, :description)
        end
      end
    end
  end
end
