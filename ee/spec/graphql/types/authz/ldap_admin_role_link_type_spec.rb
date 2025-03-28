# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['LdapAdminRoleLink'], feature_category: :permissions do
  it { expect(described_class.graphql_name).to eq('LdapAdminRoleLink') }

  describe 'fields' do
    let(:fields) { %i[id admin_member_role provider filter cn] }

    it { expect(described_class).to have_graphql_fields(fields) }
  end
end
