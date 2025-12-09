# frozen_string_literal: true

module API
  module Entities
    class ManagedLicense < Grape::Entity
      expose :id, :name, :approval_status
    end
  end
end
