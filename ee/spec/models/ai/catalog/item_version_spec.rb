# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemVersion, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:item).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:definition) }
    it { is_expected.to validate_presence_of(:schema_version) }
    it { is_expected.to validate_presence_of(:version) }

    it { is_expected.to validate_length_of(:version).is_at_most(50) }

    it 'definition validates json_schema' do
      validator = described_class.validators_on(:definition).find { |v| v.is_a?(JsonSchemaValidator) }

      expect(validator.options[:filename]).to eq('ai_catalog_item_version_definition')
      expect(validator.instance_variable_get(:@size_limit)).to eq(64.kilobytes)
    end

    describe '#validate_readonly' do
      it 'can be changed if version is draft' do
        version = create(:ai_catalog_item_version, release_date: nil)
        version.release_date = Time.zone.now

        expect(version).to be_valid
      end

      it 'cannot be changed if version is released' do
        version = create(:ai_catalog_item_version, release_date: 1.day.ago)
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

    it 'returns version prefixed with v' do
      expect(
        build(:ai_catalog_item_version, release_date: Time.zone.now, version: '1.2.3').human_version
      ).to eq('v1.2.3')
    end

    it 'returns version suffixed with -draft when draft' do
      expect(build(:ai_catalog_item_version, release_date: nil, version: '1.2.3').human_version).to eq('v1.2.3-draft')
    end
  end

  describe '#read_only?' do
    it 'returns false when release_date is nil and not read only' do
      expect(create(:ai_catalog_item_version, release_date: nil)).not_to be_readonly
    end

    it 'returns true when release_date is present' do
      expect(create(:ai_catalog_item_version, release_date: Time.zone.now)).to be_readonly
    end

    it 'returns true when record is read only' do
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
end
