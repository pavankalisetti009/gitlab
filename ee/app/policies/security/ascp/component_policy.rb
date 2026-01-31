# frozen_string_literal: true

module Security
  module Ascp
    class ComponentPolicy < BasePolicy
      delegate { @subject.project }

      rule { can?(:read_security_resource) }.enable :read_ascp_component
    end
  end
end
