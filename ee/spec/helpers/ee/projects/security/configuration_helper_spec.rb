# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Projects::Security::ConfigurationHelper do
  let_it_be(:project) { create(:project) }

  let(:current_user) { create(:user) }

  before do
    helper.instance_variable_set(:@project, project)
  end

  describe 'security_upgrade_path' do
    subject { helper.security_upgrade_path }

    before do
      allow(helper).to receive(:show_discover_project_security?).and_return(can_access_discover_security)
    end

    context 'when user can access discover security' do
      let(:can_access_discover_security) { true }

      it { is_expected.to eq(project_security_discover_path(project)) }
    end

    context 'when user can not access discover security' do
      let(:can_access_discover_security) { false }

      it { is_expected.to eq(promo_pricing_url) }
    end
  end

  describe 'group_configuration_path' do
    subject { helper.group_configuration_path }

    it { is_expected.to eq(group_security_configuration_path(project.root_ancestor)) }
  end
end
