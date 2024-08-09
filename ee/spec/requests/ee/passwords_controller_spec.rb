# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PasswordsController, type: :request, feature_category: :system_access do
  let(:params) { { password: 'aaaaaaaa' } }

  describe 'POST #complexity' do
    subject(:password_complexity_validation) { post users_password_complexity_path, params: params }

    it 'returns JSON response' do
      password_complexity_validation

      expect(json_response).to eq('common' => true)
    end

    context 'when password is missing' do
      let(:params) { {} }

      it 'raises an error' do
        expect { password_complexity_validation }.to raise_error(ActionController::ParameterMissing)
      end
    end
  end
end
