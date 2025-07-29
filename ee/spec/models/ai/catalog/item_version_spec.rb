# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemVersion, feature_category: :workflow_catalog do
  subject(:version) { build_stubbed(:ai_catalog_item_version) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:item).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:definition) }
    it { is_expected.to validate_presence_of(:schema_version) }
    it { is_expected.to validate_presence_of(:version) }

    it { is_expected.to validate_length_of(:version).is_at_most(50) }

    describe 'definition json_schema' do
      context 'when item is an agent' do
        subject(:version) { build_stubbed(:ai_catalog_agent_version) }

        it { is_expected.to be_valid }

        context 'when definition is invalid' do
          before do
            version.definition['system_prompt'] = nil
          end

          it { is_expected.not_to be_valid }
        end
      end

      context 'when item is a flow' do
        subject(:version) { build_stubbed(:ai_catalog_flow_version) }

        it { is_expected.to be_valid }

        context 'when definition is invalid' do
          before do
            version.definition['something'] = 1
          end

          it { is_expected.not_to be_valid }
        end
      end
    end

    describe '#validate_readonly' do
      it 'can be changed if version is draft' do
        version = create(:ai_catalog_item_version)
        version.release_date = Time.zone.now

        expect(version).to be_valid
      end

      it 'cannot be changed if version is released' do
        version = create(:ai_catalog_item_version, :released)
        version.release_date = Time.zone.now

        expect(version).not_to be_valid
        expect(version.errors[:base]).to include('cannot change a released item version')
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create :populate_organization' do
      subject(:version) { create(:ai_catalog_item_version) }

      it 'assigns organization from item' do
        expect(version.organization).to eq(version.item.organization)
      end
    end
  end

  describe '#human_version' do
    it 'returns nil when version is nil' do
      expect(build(:ai_catalog_item_version, version: nil).human_version).to be_nil
    end

    it 'returns version prefixed with v when released' do
      expect(
        build(:ai_catalog_item_version, :released, version: '1.2.3').human_version
      ).to eq('v1.2.3')
    end

    it 'returns version prefixed with v and suffixed with -draft when draft' do
      expect(build(:ai_catalog_item_version, version: '1.2.3').human_version).to eq('v1.2.3-draft')
    end
  end

  describe '#read_only?' do
    it 'returns false when draft' do
      expect(create(:ai_catalog_item_version)).not_to be_readonly
    end

    it 'returns true when released' do
      expect(create(:ai_catalog_item_version, :released)).to be_readonly
    end

    it 'returns true when draft record is read only' do
      item = create(:ai_catalog_item_version)
      item.readonly!

      expect(item).to be_readonly
    end
  end

  describe '#released?' do
    it 'returns false when release_date is nil' do
      expect(build(:ai_catalog_item_version, release_date: nil)).not_to be_released
    end

    it 'returns true when release_date is present' do
      expect(build(:ai_catalog_item_version, release_date: Time.zone.now)).to be_released
    end
  end

  describe '#draft?' do
    it 'returns true when release_date is nil' do
      expect(build(:ai_catalog_item_version, release_date: nil)).to be_draft
    end

    it 'returns false when release_date is present' do
      expect(build(:ai_catalog_item_version, release_date: Time.zone.now)).not_to be_draft
    end
  end

  describe '#respond_to?' do
    subject(:version) { build_stubbed(:ai_catalog_item_version) }

    context 'when method starts with "def_"' do
      it 'returns true' do
        expect(version.respond_to?(:def_system_prompt)).to be(true)
      end
    end

    context 'when method does not start with "def_"' do
      it 'returns false' do
        expect(version.respond_to?(:unknown_method)).to be(false)
      end
    end
  end

  describe '#method_missing' do
    subject(:version) { build_stubbed(:ai_catalog_item_version) }

    it 'provides access to top level definition attributes' do
      expect(version.def_system_prompt).to eq('Talk like a pirate!')
    end
  end
end
