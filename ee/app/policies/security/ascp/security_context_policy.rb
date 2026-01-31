# frozen_string_literal: true

module Security
  module Ascp
    class SecurityContextPolicy < BasePolicy
      delegate { @subject.project }

      rule { can?(:read_security_resource) }.enable :read_ascp_security_context
    end
  end
end
