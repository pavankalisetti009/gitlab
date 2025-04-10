# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Access, :models, feature_category: :cloud_connector do
  describe 'validations' do
    let_it_be(:cloud_connector_access) { create(:cloud_connector_access) }

    subject { cloud_connector_access }

    it { is_expected.to validate_presence_of(:data) }

    context 'when writing to the catalog field' do
      let(:cloud_connector_access) { build(:cloud_connector_access, catalog: catalog) }

      context 'when valid catalog JSON is provided' do
        let(:catalog) { { "backend_services" => [] } }

        it 'is valid' do
          expect(cloud_connector_access.valid?).to be true
        end
      end

      context 'when invalid catalog JSON is provided' do
        let(:catalog) { [] }

        it 'is invalid' do
          expect(cloud_connector_access.valid?).to be false
          expect(cloud_connector_access.errors[:catalog]).to match_array ['must be a valid json schema']
        end
      end

      context 'when no catalog JSON is provided' do
        let(:catalog) { nil }

        it 'is valid' do
          expect(cloud_connector_access.valid?).to be true
        end
      end
    end
  end
end
