# frozen_string_literal: true

module API
  module Entities
    module VirtualRegistries
      module Packages
        module Maven
          class Upstream < Grape::Entity
            expose :id, :name, :description, :group_id, :url, :cache_validity_hours, :created_at, :updated_at
            expose :registry_upstream,
              if: ->(_upstream, options) { options[:with_registry_upstream] },
              using: RegistryUpstream
          end
        end
      end
    end
  end
end
