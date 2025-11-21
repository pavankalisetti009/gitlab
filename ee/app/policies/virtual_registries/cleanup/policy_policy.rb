# frozen_string_literal: true

module VirtualRegistries
  module Cleanup
    class PolicyPolicy < ::BasePolicy
      delegate { ::VirtualRegistries::Policies::Group.new(@subject.group) }
    end
  end
end
