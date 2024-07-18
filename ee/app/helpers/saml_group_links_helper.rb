# frozen_string_literal: true

module SamlGroupLinksHelper
  def saml_group_link_input_names
    {
      base_access_level_input_name: "saml_group_link[access_level]",
      member_role_id_input_name: "saml_group_link[member_role_id]"
    }
  end
end
