# frozen_string_literal: true

module VirtualRegistries
  module Container
    class RegistryPolicy < ::BasePolicy
      delegate { ::VirtualRegistries::Policies::Group.new(@subject.group) }
    end
  end
end
