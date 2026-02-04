# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Npm
      class UpstreamPolicy < ::BasePolicy
        delegate { ::VirtualRegistries::Policies::Group.new(@subject.group) }
      end
    end
  end
end
