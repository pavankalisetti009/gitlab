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
    if container && Feature.enabled?(:update_organization_push_rules, Feature.current_request)
      OrganizationPushRule.find_by(organization: container) # rubocop: disable CodeReuse/ActiveRecord -- extracted for finder use
    else
      PushRule.find_by(is_sample: true) # rubocop: disable CodeReuse/ActiveRecord -- extracted for finder use
    end
  end
end
