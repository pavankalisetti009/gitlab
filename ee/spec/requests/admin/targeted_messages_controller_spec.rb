# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::TargetedMessagesController, :enable_admin_mode, :saas, feature_category: :acquisition do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:targeted_message) { build(:targeted_message) }
  let(:invalid_targeted_message_params) { { targeted_message: { target_type: '' } } }
  let(:targeted_message_params) { targeted_message.as_json(root: true) }

  before do
    sign_in(admin)
  end

  describe 'GET #index' do
    it 'renders index template' do
      get admin_targeted_messages_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to render_template(:index)
    end
  end

  describe 'GET #new' do
    it 'renders new template' do
      get new_admin_targeted_message_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to render_template(:new)
    end
  end

  describe 'GET #edit' do
    before do
      targeted_message.save!
    end

    it 'renders edit template' do
      get edit_admin_targeted_message_path(targeted_message)
      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to render_template(:edit)
    end
  end

  describe 'POST #create' do
    it 'persists the message and redirects to index on success' do
      post admin_targeted_messages_path, params: targeted_message_params
      expect(response).to redirect_to(admin_targeted_messages_path)
      expect(flash[:notice]).to eq('Targeted message was successfully created.')
    end

    it 'does not persist and renders the new page on failure' do
      post admin_targeted_messages_path, params: invalid_targeted_message_params
      expect(response.body).to render_template(:new)
      expect(flash[:alert]).to eq("Failed to create targeted message: Target type can't be blank")
    end

    context 'with targeted message namespace ids' do
      let(:valid_namespace) { create(:namespace) }
      let(:valid_namespace_id) { valid_namespace.id }
      let(:invalid_namespace_ids) { [123456] }
      let(:stubbed_file) { 'stubbed csv file' }

      let(:targeted_message_params_with_csv) do
        targeted_message_params.deep_symbolize_keys.deep_merge(targeted_message: { namespace_ids_csv: stubbed_file })
      end

      context 'when successfully processing csv' do
        before do
          allow_next_instance_of(Notifications::TargetedMessages::ProcessCsvService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.success(payload: {
                valid_namespace_ids: [valid_namespace_id],
                invalid_namespace_ids: invalid_namespace_ids
              }))
          end
        end

        it 'processes CSV, assigns valid namespace ids and sets flash alert for invalid namespace ids' do
          expect { post admin_targeted_messages_path, params: targeted_message_params_with_csv }.to change {
            Notifications::TargetedMessage.count
          }.by(1)
          expect(Notifications::TargetedMessage.last.targeted_message_namespaces.map(&:namespace_id))
            .to contain_exactly(valid_namespace_id)
          expect(flash[:warning])
            .to eq("The following namespace ids were invalid and have been ignored: #{invalid_namespace_ids.join}")
        end

        context 'with invalid namespace ids being more than 5' do
          let(:invalid_namespace_ids) { [12345, 22345, 32345, 42345, 52345, 62345] }

          it 'processes CSV and truncate invalid namespace ids in flash message' do
            expect { post admin_targeted_messages_path, params: targeted_message_params_with_csv }.to change {
              Notifications::TargetedMessage.count
            }.by(1)
            expect(flash[:warning])
              .to eq("The following namespace ids were invalid and have been ignored: " \
                "#{invalid_namespace_ids.first(5).join(', ')} and 1 more")
          end
        end
      end

      context 'with errors from process csv' do
        it 'creates the message but does not assign any namespace ids' do
          allow_next_instance_of(Notifications::TargetedMessages::ProcessCsvService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'StandardError'))
          end

          expect { post admin_targeted_messages_path, params: targeted_message_params_with_csv }.to change {
            Notifications::TargetedMessage.count
          }.by(1)
          expect(Notifications::TargetedMessage.last.targeted_message_namespaces).to be_empty
          expect(flash[:warning])
            .to eq("Failed to assign namespaces due to error processing CSV: StandardError")
        end
      end
    end
  end

  describe 'PATCH #update' do
    let_it_be(:targeted_message, reload: true) { create(:targeted_message) }

    it 'updates the message and redirects to index on success' do
      patch admin_targeted_message_path(targeted_message), params: targeted_message_params
      expect(response).to redirect_to(admin_targeted_messages_path)
      expect(flash[:notice]).to eq('Targeted message was successfully updated.')
    end

    it 'does not update and renders the edit page on failure' do
      patch admin_targeted_message_path(targeted_message), params: invalid_targeted_message_params
      expect(response.body).to render_template(:edit)
      expect(flash[:alert]).to eq("Failed to update targeted message: Target type can't be blank")
    end

    context 'with updating targeted message namespace ids' do
      let_it_be(:old_targeted_namespaces) do
        create_list(:targeted_message_namespace, 3, targeted_message: targeted_message)
      end

      let(:old_targeted_namespace_ids) { old_targeted_namespaces.map(&:namespace_id) }
      let_it_be(:new_targeted_namespace_ids) { [create(:namespace).id, create(:namespace).id] }
      let(:targeted_message_params_with_csv) do
        targeted_message_params.deep_symbolize_keys.deep_merge(targeted_message: { namespace_ids_csv: 'stubbed_file' })
      end

      before do
        allow_next_instance_of(Notifications::TargetedMessages::ProcessCsvService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: {
              valid_namespace_ids: new_targeted_namespace_ids,
              invalid_namespace_ids: []
            }))
        end
      end

      it 'replaces targeted namespaces with new set' do
        expect(targeted_message.targeted_message_namespaces.map(&:namespace_id))
          .to match(old_targeted_namespace_ids)

        patch admin_targeted_message_path(targeted_message), params: targeted_message_params_with_csv

        expect(targeted_message.reload.targeted_message_namespaces.map(&:namespace_id))
          .to match(new_targeted_namespace_ids)
      end
    end
  end
end
