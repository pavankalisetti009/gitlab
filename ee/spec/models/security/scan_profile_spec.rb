# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfile, feature_category: :security_asset_inventories do
  let_it_be(:root_level_group) { create(:group) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:scan_type) }
    it { is_expected.to validate_inclusion_of(:gitlab_recommended).in_array([true, false]) }
    it { is_expected.to validate_length_of(:description).is_at_most(2047) }

    context 'when validating uniqueness of name scoped to namespace and type' do
      subject { create(:security_scan_profile, namespace: root_level_group, scan_type: :sast) }

      it { is_expected.to validate_uniqueness_of(:name).scoped_to([:namespace_id, :scan_type]) }
    end

    describe '#root_namespace_validation' do
      let_it_be(:subgroup) { create(:group, parent: root_level_group) }

      it 'is valid for root group namespace' do
        expect(build(:security_scan_profile, namespace: root_level_group)).to be_valid
      end

      it 'is invalid for non-root namespaces' do
        profile = build(:security_scan_profile, namespace: subgroup)

        expect(profile).not_to be_valid
        expect(profile.errors[:namespace]).to include('must be a root namespace.')
      end
    end
  end

  describe 'scopes' do
    let_it_be(:scan_profile_1) { create(:security_scan_profile, namespace: root_level_group, name: "profile 1") }
    let_it_be(:scan_profile_2) { create(:security_scan_profile, namespace: root_level_group, name: "profile 2") }

    describe '.with_trigger_type' do
      let_it_be(:git_push_trigger_1) do
        create(:security_scan_profile_trigger,
          namespace: root_level_group,
          scan_profile: scan_profile_1,
          trigger_type: :git_push_event)
      end

      it 'returns scan profiles with the specified trigger type' do
        result = described_class.with_trigger_type(:git_push_event)

        expect(result).to contain_exactly(scan_profile_1)
      end

      it 'returns empty relation when no profiles have the specified trigger type' do
        result = described_class.with_trigger_type(:default_branch_pipeline)

        expect(result).to be_empty
      end
    end

    describe '.by_gitlab_recommended' do
      let_it_be(:profile) { create(:security_scan_profile, namespace: root_level_group, scan_type: :secret_detection) }
      let_it_be(:gitlab_recommended_profile) do
        create(:security_scan_profile,
          namespace: root_level_group,
          scan_type: :secret_detection,
          gitlab_recommended: true,
          name: "gitlab_recommended_profile"
        )
      end

      it 'returns gitlab recommended profiles' do
        expect(described_class.by_gitlab_recommended).to match_array([gitlab_recommended_profile])
      end
    end
  end

  describe 'class methods' do
    let_it_be(:scan_profile_1) { create(:security_scan_profile, namespace: root_level_group, name: "profile 1") }
    let_it_be(:scan_profile_2) { create(:security_scan_profile, namespace: root_level_group, name: "profile 2") }

    describe '.scan_profile_ids' do
      context 'when there are fewer records than MAX_PLUCK' do
        it 'returns all ids' do
          result = described_class.scan_profile_ids

          expect(result.count).to eq(2)
        end
      end

      context 'when there are more records than MAX_PLUCK' do
        before do
          stub_const("#{described_class}::MAX_PLUCK", 1)
        end

        it 'limits the number of ids returned to MAX_PLUCK' do
          result = described_class.scan_profile_ids

          expect(result.count).to eq(1)
        end
      end
    end
  end

  describe 'attribute stripping' do
    it 'strips whitespace from name' do
      scan_profile = build(:security_scan_profile, name: '  Test Profile  ')
      scan_profile.valid?
      expect(scan_profile.name).to eq('Test Profile')
    end

    it 'strips whitespace from description' do
      scan_profile = build(:security_scan_profile, description: '  Test Description  ')
      scan_profile.valid?
      expect(scan_profile.description).to eq('Test Description')
    end
  end

  describe 'nested attributes' do
    describe 'scan_profile_triggers' do
      let(:triggers_attributes) { [] }
      let(:base_attributes) do
        {
          namespace: root_level_group,
          scan_type: :secret_detection,
          name: 'Test Profile'
        }
      end

      let(:profile) do
        described_class.new(base_attributes.merge(scan_profile_triggers_attributes: triggers_attributes))
      end

      context 'with single trigger' do
        let(:triggers_attributes) { [{ trigger_type: :git_push_event }] }

        it 'sets namespace on scan_profile_trigger before validation' do
          profile.valid?
          expect(profile.scan_profile_triggers.first.namespace).to eq(root_level_group)
        end

        it 'persists scan_profile_trigger on save' do
          expect { profile.save! }.to change { Security::ScanProfileTrigger.count }.by(1)
          expect(profile.scan_profile_triggers.first).to have_attributes(
            trigger_type: 'git_push_event',
            namespace: root_level_group
          )
        end
      end

      context 'with multiple triggers' do
        let(:triggers_attributes) do
          [
            { trigger_type: :git_push_event },
            { trigger_type: :default_branch_pipeline }
          ]
        end

        it 'sets namespace on multiple triggers before validation' do
          profile.valid?
          expect(profile.scan_profile_triggers).to all(have_attributes(namespace: root_level_group))
        end

        it 'persists multiple triggers on save' do
          expect { profile.save! }.to change { Security::ScanProfileTrigger.count }.by(2)
          expect(profile.scan_profile_triggers).to all(have_attributes(namespace: root_level_group))
          expect(profile.scan_profile_triggers.pluck(:trigger_type))
            .to match_array(%w[git_push_event default_branch_pipeline])
        end
      end

      context 'when trigger already has a namespace' do
        let_it_be(:another_group) { create(:group) }
        let(:triggers_attributes) { [{ trigger_type: :git_push_event, namespace: another_group }] }

        it 'does not override existing namespace' do
          profile.valid?
          expect(profile.scan_profile_triggers.first.namespace).to eq(another_group)
        end
      end
    end
  end

  context 'with loose foreign key on security_scan_profiles.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { root_level_group }
      let_it_be(:model) { create(:security_scan_profile, namespace: parent) }
    end
  end
end
