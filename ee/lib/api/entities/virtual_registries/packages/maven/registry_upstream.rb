# frozen_string_literal: true

module API
  module Entities
    module VirtualRegistries
      module Packages
        module Maven
          class RegistryUpstream < Grape::Entity
            expose :id, :position
          end
        end
      end
    end
  end
end
