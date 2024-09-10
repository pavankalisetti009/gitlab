# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectSecurityExclusion, feature_category: :secret_detection, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:scanner) }
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to allow_value(true, false).for(:active) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_length_of(:value).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:scanner).with_values([:secret_push_protection]) }
    it { is_expected.to define_enum_for(:type).with_values([:path, :regex_pattern, :raw_value, :rule]) }
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:exclusion_1) { create(:project_security_exclusion, project: project) }
    let_it_be(:exclusion_2) { create(:project_security_exclusion, project: project, active: false) }
    let_it_be(:exclusion_3) { create(:project_security_exclusion, project: project, type: :path) }

    describe '.by_scanner' do
      it 'returns the correct records' do
        expect(described_class.by_scanner(:secret_push_protection)).to match_array([exclusion_1, exclusion_2,
          exclusion_3])
      end
    end

    describe '.by_type' do
      it 'returns the correct records' do
        expect(described_class.by_type(:raw_value)).to match_array([exclusion_1, exclusion_2])
      end
    end

    describe '.by_status' do
      it 'returns the correct records' do
        expect(described_class.by_status(true)).to match_array([exclusion_1, exclusion_3])
      end
    end
  end

  context 'with loose foreign key on project_security_exclusions.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:project_security_exclusion, project: parent) }
    end
  end
end
