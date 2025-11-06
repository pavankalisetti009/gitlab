# frozen_string_literal: true

class PushRuleFinder
  def initialize(container = nil)
    @container = container
  end

  def execute
    global_rule
  end

  private

  attr_reader :container

  def global_rule
    if container && read_or_write_flag_enabled?
      OrganizationPushRule.find_by(organization: container) # rubocop: disable CodeReuse/ActiveRecord -- extracted for finder use
    else
      PushRule.find_by(is_sample: true) # rubocop: disable CodeReuse/ActiveRecord -- extracted for finder use
    end
  end

  def read_or_write_flag_enabled?
    # ideally read_organization_push_rules should be on for update_organization_push_rules to be turned on
    # read_organization_push_rules FF should be removed first when cleanup is happening

    Feature.enabled?(:read_organization_push_rules,
      Feature.current_request) || Feature.enabled?(:update_organization_push_rules, Feature.current_request)
  end
end
