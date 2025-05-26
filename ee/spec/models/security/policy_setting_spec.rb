# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicySetting, feature_category: :security_policy_management, type: :model do
  subject(:settings) { build(:security_policy_settings) }

  describe 'associations' do
    it { is_expected.to belong_to(:csp_namespace).optional.class_name('Group') }
  end

  describe 'validations' do
    describe 'csp_namespace' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:child_group) { create(:group, parent: parent_group) }

      it_behaves_like 'cleanup by a loose foreign key' do
        let_it_be(:parent) { create(:group) }
        let_it_be(:model) { create(:security_policy_settings, csp_namespace: parent) }
        let(:lfk_column) { :csp_namespace_id }
      end

      it 'can be assigned a top level group' do
        settings.update!(csp_namespace: parent_group)
        expect(settings.csp_namespace).to eq(parent_group)
      end

      it 'cannot be assigned a child group' do
        expect do
          settings.update!(csp_namespace: child_group)
        end.to raise_error(ActiveRecord::RecordInvalid,
          'Validation failed: CSP namespace must be a top level Group')
      end

      it 'cannot be assigned a user namespace' do
        user = create(:user, :with_namespace)
        settings.csp_namespace_id = user.namespace.id

        expect(settings).to be_invalid
        expect(settings.errors[:csp_namespace]).to include('must be a group')
      end
    end

    it_behaves_like 'singleton record validation' do
      it 'allows updating the existing record' do
        setting = described_class.create!

        setting.csp_namespace = build(:group)

        expect(setting).to be_valid
      end
    end
  end

  describe '.instance' do
    context 'when an entry does not exist' do
      it 'creates an entry' do
        expect { described_class.instance }.to change { described_class.count }.by(1)
      end

      it 'sets default attributes' do
        expect(described_class.instance).to have_attributes(csp_namespace_id: nil)
      end
    end

    context 'when an entry exists' do
      let_it_be(:settings) { create(:security_policy_settings, csp_namespace: create(:group)) }

      it 'does not create a new entry' do
        expect { described_class.instance }.not_to change { described_class.count }
      end

      it 'returns the existing entry' do
        expect(described_class.instance).to eq(settings)
      end
    end
  end

  describe '.csp_enabled?' do
    include Security::PolicyCspHelpers

    subject { described_class.csp_enabled?(group) }

    let(:group) { top_level_group }
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: top_level_group) }

    it { is_expected.to be(false) }

    context 'when the group is designated as a CSP group' do
      before do
        stub_csp_group(group)
      end

      it { is_expected.to be(true) }

      context 'when on GitLab.com', :saas do
        it { is_expected.to be(false) }
      end

      context 'when feature flag "security_policies_csp" is disabled' do
        before do
          stub_feature_flags(security_policies_csp: false)
        end

        it { is_expected.to be(false) }
      end

      context 'with subgroup and feature flag "security_policies_csp" enabled for the root ancestor' do
        let(:group) { subgroup }

        before do
          stub_feature_flags(security_policies_csp: top_level_group)
        end

        it { is_expected.to be(true) }
      end
    end
  end
end
