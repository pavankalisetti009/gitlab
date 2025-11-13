# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Profiles::PreferencesController, feature_category: :user_profile do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe 'PATCH update' do
    context 'when updating security dashboard feature' do
      subject { patch :update, params: { user: { group_view: group_view } }, format: :json }

      let(:group_view) { 'security_dashboard' }

      context 'when the security dashboard feature is enabled' do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        context 'and valid group view choice is submitted' do
          it "changes the user's preferences" do
            expect { subject }.to change { user.reload.group_view_security_dashboard? }.from(false).to(true)
          end

          context 'and an invalid group view choice is submitted' do
            let(:group_view) { 'foo' }

            it 'responds with an error message' do
              subject

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(response.parsed_body['message']).to match(/Failed to save preferences/)
              expect(response.parsed_body['type']).to eq('alert')
            end
          end
        end
      end

      context 'when the security dashboard feature is disabled' do
        context 'when security dashboard feature enabled' do
          specify do
            expect { subject }.not_to change { user.reload.group_view_security_dashboard? }
          end
        end
      end
    end

    context 'when updating default duo group' do
      let!(:user_preference) { create(:user_preference, user: user) }
      let(:namespace) { create(:group) }
      let(:add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace) }
      let(:user_assignment) do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end

      subject do
        patch :update,
          params: { user: { user_preference_attributes:
          { default_duo_add_on_assignment_id: user_assignment.id } } }
      end

      context "when assign default duo group is not allowed" do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :assign_default_duo_group, user).and_return(false)
        end

        it 'does not update default_duo_add_on_assignment_id' do
          expect { subject }.not_to change {
            user_preference.reload.default_duo_add_on_assignment_id
          }
        end
      end

      context "when assign default duo group is allowed" do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :assign_default_duo_group, user).and_return(true)
        end

        it 'updates default_duo_add_on_assignment_id' do
          expect { subject }.to change {
            user_preference.reload.default_duo_add_on_assignment_id
          }.from(nil).to(user_assignment.id)
        end
      end
    end
  end
end
