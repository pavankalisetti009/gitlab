# frozen_string_literal: true

module Security
  class AttributePolicy < BasePolicy
    delegate { @subject.namespace }

    rule { can?(:admin_security_attributes) }.policy do
      enable :read_security_attribute
    end
  end
end
