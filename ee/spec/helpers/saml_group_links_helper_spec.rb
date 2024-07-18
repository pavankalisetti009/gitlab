# frozen_string_literal: true

require "spec_helper"

RSpec.describe SamlGroupLinksHelper, feature_category: :system_access do
  describe '#saml_group_link_input_names' do
    subject(:saml_group_link_input_names) { helper.saml_group_link_input_names }

    it 'returns the correct data' do
      expected_data = {
        base_access_level_input_name: "saml_group_link[access_level]",
        member_role_id_input_name: "saml_group_link[member_role_id]"
      }

      expect(saml_group_link_input_names).to match(hash_including(expected_data))
    end
  end
end
