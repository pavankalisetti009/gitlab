# frozen_string_literal: true

module VirtualRegistries
  class SettingPolicy < ::BasePolicy
    delegate { ::VirtualRegistries::Policies::Group.new(@subject.group) }
  end
end
