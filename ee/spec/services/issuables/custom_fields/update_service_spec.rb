# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFields::UpdateService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let(:custom_field) { create(:custom_field, namespace: group) }

  let(:params) { { name: 'new custom field name' } }
  let(:response) do
    described_class.new(custom_field: custom_field, current_user: user, params: params).execute
  end

  let(:updated_custom_field) { response.payload[:custom_field] }

  before do
    stub_licensed_features(custom_fields: true)
  end

  context 'with valid params' do
    it 'updates the custom field and sets updated_by' do
      expect(response).to be_success
      expect(updated_custom_field).to be_persisted
      expect(updated_custom_field.name).to eq('new custom field name')
      expect(updated_custom_field.updated_by_id).to eq(user.id)
    end
  end

  context 'when there are no changes' do
    let(:params) { { name: custom_field.name } }

    it 'does not set updated_by' do
      expect(response).to be_success
      expect(updated_custom_field.updated_by_id).to be_nil
    end
  end

  context 'when user does not have access' do
    let(:user) { create(:user, guest_of: group) }

    it 'returns an error' do
      expect(response).to be_error
      expect(response.message).to eq(described_class::NotAuthorizedError.message)
    end
  end

  context 'when custom_fields_feature is disabled' do
    before do
      stub_feature_flags(custom_fields_feature: false)
    end

    it 'returns an error' do
      expect(response).to be_error
      expect(response.message).to eq(described_class::FeatureNotAvailableError.message)
    end
  end

  context 'when there are model validation errors' do
    let(:params) { { name: 'a' * 256 } }

    it 'returns the validation error' do
      expect(response).to be_error
      expect(response.message).to include('Name is too long (maximum is 255 characters)')
    end
  end
end
