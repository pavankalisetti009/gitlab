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

    it { is_expected.to allow_value('1.1.1', '999.999.999').for(:version) }
    it { is_expected.not_to allow_value('1.1.1.', '1.1', '1', "hello\n1.0.0\nworld").for(:version) }

    describe 'definition json_schema' do
      context 'when item is an agent' do
        subject(:version) { build_stubbed(:ai_catalog_agent_version) }

        it { is_expected.to be_valid }

        context 'when definition is invalid' do
          before do
            version.definition['something'] = 1
          end

          it { is_expected.not_to be_valid }
        end

        context 'when user_prompt is an empty string' do
          before do
            version.definition['user_prompt'] = ''
          end

          it { is_expected.to be_valid }
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

        context 'when definition has invalid types for required properties' do
          before do
            version.definition['version'] = 123
            version.definition['environment'] = nil
            version.definition['components'] = 'not an array'
            version.definition['routers'] = true
            version.definition['flow'] = 'not an object'
          end

          it "adds validation errors for each invalid property type and value" do
            expect(version).not_to be_valid
            expect(version.errors['definition']).to contain_exactly(
              "value at `/version` is not a string",
              "value at `/version` is not: v1",
              "value at `/environment` is not a string",
              "value at `/environment` is not one of: [\"ambient\"]",
              "value at `/components` is not an array",
              "value at `/routers` is not an array",
              "value at `/flow` is not an object"
            )
          end
        end
      end

      context 'when item is third party flow' do
        subject(:version) { build_stubbed(:ai_catalog_third_party_flow_version) }

        it { is_expected.to be_valid }

        context 'when definition has invalid image, commands, injectGatewayToken or variables' do
          before do
            version.definition['image'] = 123
            version.definition['commands'] = { a: :b }
            version.definition['injectGatewayToken'] = 'yes'
            version.definition['variables'] = nil
          end

          it "adds errors for all the attributes" do
            expect(version).not_to be_valid
            expect(version.errors['definition']).to contain_exactly(
              "value at `/commands` is not an array",
              "value at `/image` is not a string",
              "value at `/injectGatewayToken` is not a boolean",
              "value at `/variables` is not an array"
            )
          end
        end
      end

      context 'when item is nil' do
        it 'cannot validate definition schema' do
          version.item = nil

          expect(version).not_to be_valid
          expect(version.errors[:definition]).to include('unable to validate definition')
        end
      end

      context 'when schema_version is nil' do
        it 'cannot validate definition schema' do
          version.schema_version = nil

          expect(version).not_to be_valid
          expect(version.errors[:definition]).to include('unable to validate definition')
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
        expect(version.errors[:base]).to include('cannot be changed as it has been released')
      end

      context 'when `ai_catalog_enforce_readonly_versions` feature is disabled' do
        before do
          stub_feature_flags(ai_catalog_enforce_readonly_versions: false)
        end

        it 'can be changed if version is released' do
          version = create(:ai_catalog_item_version, :released)
          version.release_date = Time.zone.now

          expect(version).to be_valid
        end
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

  describe '#version_bump' do
    subject(:version) { build(:ai_catalog_item_version, version: '1.2.3') }

    it 'returns nil if version is nil' do
      version.version = nil

      expect(version.version_bump(:major)).to be_nil
    end

    it 'can return major version bunp' do
      expect(version.version_bump(:major)).to eq('2.0.0')
    end

    it 'can return minor version bunp' do
      expect(version.version_bump(:minor)).to eq('1.3.0')
    end

    it 'can return patch version bunp' do
      expect(version.version_bump(:patch)).to eq('1.2.4')
    end

    it 'raises an error if bump level is unknown' do
      expect { version.version_bump(:foo) }.to raise_error(ArgumentError, 'unknown bump_level: foo')
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
