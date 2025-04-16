# frozen_string_literal: true

module Groups
  class VirtualRegistriesController < Groups::VirtualRegistries::BaseController
    before_action :verify_read_virtual_registry!

    feature_category :virtual_registry
    urgency :low

    def index; end
  end
end
