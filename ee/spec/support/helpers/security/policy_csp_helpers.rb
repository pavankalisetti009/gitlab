# frozen_string_literal: true

module Security
  module PolicyCspHelpers
    def stub_csp_group(group)
      allow(Security::PolicySetting).to receive(:instance).and_return(
        instance_double(Security::PolicySetting, csp_namespace_id: group.id)
      )
    end
  end
end
