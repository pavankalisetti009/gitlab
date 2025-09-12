# frozen_string_literal: true

module VirtualRegistries
  module Container
    class RegistryPolicy < ::BasePolicy
      delegate { ::VirtualRegistries::Packages::Policies::Group.new(@subject.group) }
    end
  end
end
