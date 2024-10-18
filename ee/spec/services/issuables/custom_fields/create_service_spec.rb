# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFields::CreateService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let(:params) { { name: 'my custom field', field_type: 'text' } }
  let(:response) { described_class.new(group: group, current_user: user, params: params).execute }
  let(:custom_field) { response.payload[:custom_field] }

  before do
    stub_licensed_features(custom_fields: true)
  end

  context 'with valid params' do
    it 'creates a custom field and sets created_by' do
      expect(response).to be_success
      expect(custom_field).to be_persisted
      expect(custom_field.name).to eq('my custom field')
      expect(custom_field.field_type).to eq('text')
      expect(custom_field.created_by_id).to eq(user.id)
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
    let(:params) { { name: 'a' * 256, field_type: 'text' } }

    it 'returns the validation error' do
      expect(response).to be_error
      expect(response.message).to include('Name is too long (maximum is 255 characters)')
    end
  end
end
