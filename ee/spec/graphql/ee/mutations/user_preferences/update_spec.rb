# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::UserPreferences::Update, feature_category: :user_profile do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group, :private) }

  before_all do
    current_user.user_preference.save!
  end

  subject(:mutation) do
    described_class.new(object: nil, context: query_context(user: current_user), field: nil)
  end

  describe 'duo_default_namespace_id argument' do
    context 'when user has no existing preference' do
      it 'persists duo_default_namespace_id' do
        namespace.add_developer(current_user)

        result = mutation.resolve(duo_default_namespace_id: namespace.id)

        expect(result[:errors]).to be_empty
        expect(result[:user_preferences]).not_to be_nil
        expect(current_user.user_preference.persisted?).to be true
        expect(current_user.user_preference.duo_default_namespace_id).to eq(namespace.id)
      end
    end

    context 'when duo_default_namespace_id is set to nil' do
      it 'clears the duo_default_namespace_id' do
        namespace.add_developer(current_user)
        current_user.user_preference.update!(duo_default_namespace_id: namespace.id)

        result = mutation.resolve(duo_default_namespace_id: nil)

        expect(result[:errors]).to be_empty
        expect(result[:user_preferences]).not_to be_nil
        expect(current_user.user_preference.reload.duo_default_namespace_id).to be_nil
      end
    end

    context 'when user does not have access to the namespace' do
      let_it_be(:private_namespace) { create(:group, :private) }

      it 'does not set the namespace' do
        result = mutation.resolve(duo_default_namespace_id: private_namespace.id)

        expect(result[:errors]).to include("Duo default namespace specified does not allow you to execute a workflow.")
        expect(result[:user_preferences]).to be_nil
        expect(current_user.user_preference.reload.duo_default_namespace_id).to be_nil
      end
    end
  end
end
