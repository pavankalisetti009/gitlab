# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::GroupCalloutsController, feature_category: :activation do
  let_it_be(:user) { create(:user) }

  describe 'POST request_duo_agent_platform' do
    let_it_be(:group) { create(:group) }

    subject(:update_request) { post request_duo_agent_platform_group_callouts_path(namespace_id: group.id) }

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      context 'when user has membership access to the group' do
        before_all do
          group.add_developer(user)
        end

        it 'returns ok status' do
          update_request

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when service execution fails' do
          before do
            allow_next_instance_of(Users::RecordAgentPlatformCalloutService) do |service|
              allow(service).to receive(:execute).and_return(
                ServiceResponse.error(message: 'Something went wrong')
              )
            end
          end

          it 'returns unprocessable entity status' do
            update_request

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
          end

          it 'returns error message in response body' do
            update_request

            expect(response.parsed_body).to eq({ 'error' => 'Something went wrong' })
          end
        end
      end

      context 'when user does not have membership access to the group' do
        it 'returns not found' do
          update_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not signed in' do
      it 'redirects to sign in page' do
        update_request

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
