# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceHistoricalStatistic, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:letter_grade) }
    it { is_expected.to validate_presence_of(:traversal_ids) }
    it { is_expected.to validate_numericality_of(:total).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:critical).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:high).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:medium).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:low).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:unknown).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:info).is_greater_than_or_equal_to(0) }
    it { is_expected.to define_enum_for(:letter_grade).with_values(%i[a b c d f]) }
  end

  context 'with loose foreign key on vulnerability_namespace_historical_statistics.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:namespace) }
      let_it_be(:model) { create(:vulnerability_namespace_historical_statistic, namespace: parent) }
    end
  end

  describe '.by_direct_group' do
    let(:parent_group) { create(:group) }
    let(:child_group) { create(:group, parent: parent_group) }
    let!(:historical_statistic) { create(:vulnerability_namespace_historical_statistic, namespace: parent_group) }

    before do
      create(:vulnerability_namespace_historical_statistic, namespace: child_group)
    end

    subject { described_class.by_direct_group(parent_group) }

    it { is_expected.to contain_exactly(historical_statistic) }
  end
end
