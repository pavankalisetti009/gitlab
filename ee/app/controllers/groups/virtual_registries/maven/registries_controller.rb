# frozen_string_literal: true

module Groups
  module VirtualRegistries
    module Maven
      class RegistriesController < Groups::VirtualRegistries::BaseController
        before_action :verify_read_virtual_registry!, only: [:index]
        before_action :verify_create_virtual_registry!, only: [:new]

        feature_category :virtual_registry
        urgency :low

        def index; end

        def new; end
      end
    end
  end
end
