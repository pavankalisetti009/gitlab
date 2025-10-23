# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Categories::CreateService, feature_category: :security_asset_inventories do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }

  let(:params) do
    {
      name: 'name',
      description: 'description',
      editable_state: :editable,
      multiple_selection: true
    }
  end

  subject(:execute) { described_class.new(namespace: namespace, params: params, current_user: current_user).execute }

  context 'when security_categories_and_attributes feature is disabled' do
    before do
      stub_feature_flags(security_categories_and_attributes: false)
    end

    it 'raises an "access denied" error' do
      expect { execute }.to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end

  context 'when user does not have permission' do
    let(:current_user) { create(:user) }

    it 'does not create a new security category' do
      expect { execute }.not_to change { Security::Category.count }
    end

    it 'responds with an error message' do
      expect(execute.message).to eq('You are not authorized to perform this action')
    end

    it 'responds with an error service response' do
      expect(execute).to be_error
    end
  end

  context 'when namespace has a parent' do
    let_it_be(:sub_group) { create(:group, parent: namespace) }

    subject(:execute) { described_class.new(namespace: sub_group, params: params, current_user: current_user).execute }

    it 'responds with a successful service response' do
      expect(execute).to be_success
    end

    it 'creates the new category in the root namespace' do
      expect(execute.payload[:category].namespace).to eq(namespace)
    end
  end

  context 'when CreatePredefinedService returns an error' do
    let(:error_response) { ServiceResponse.error(message: 'Predefined categories error') }

    before do
      allow_next_instance_of(Security::Categories::CreatePredefinedService) do |instance|
        allow(instance).to receive(:execute).and_return(error_response)
      end
    end

    it 'does not create a new security category' do
      expect { execute }.not_to change { Security::Category.count }
    end

    it 'responds with an error service response' do
      expect(execute).to be_error
    end

    it 'returns the appropriate error message' do
      expect(execute.message).to eq('Failed to create security category')
    end
  end

  context 'when using invalid parameters' do
    context 'when name is missing' do
      subject(:execute) do
        described_class.new(namespace: namespace, params: params.except(:name), current_user: current_user)
          .execute
      end

      let(:response) { execute }

      it 'responds with an error service response' do
        expect(execute).to be_error
        expect(response.payload.messages[:name]).to contain_exactly "can't be blank"
      end

      it 'does not create a new security category' do
        allow_next_instance_of(Security::Categories::CreatePredefinedService) do |instance|
          allow(instance).to receive(:execute).and_return(ServiceResponse.success)
        end

        expect { execute }.not_to change { Security::Category.count }
      end
    end

    context 'when name is too long' do
      before do
        params[:name] = 'a' * 256
      end

      let(:response) { execute }

      it 'responds with an error service response' do
        expect(response.success?).to be false
        expect(response.payload.messages[:name]).to include "is too long (maximum is 255 characters)"
      end
    end

    context 'when description is too long' do
      before do
        params[:description] = 'a' * 256
      end

      let(:response) { execute }

      it 'responds with an error service response' do
        expect(response.success?).to be false
        expect(response.payload.messages[:description]).to include "is too long (maximum is 255 characters)"
      end
    end
  end

  context 'when namespace is not a root group' do
    let(:subgroup) { create(:group, parent: namespace) }

    subject(:execute) { described_class.new(namespace: subgroup, params: params, current_user: current_user).execute }

    it 'creates the category in the root namespace' do
      result = execute
      expect(result.success?).to be true
      expect(result.payload[:category].namespace).to eq(namespace)
    end
  end

  context 'when using parameters for a valid security category' do
    before do
      allow_next_instance_of(Security::Categories::CreatePredefinedService) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success)
      end
    end

    it 'creates a new security category' do
      expect { execute }.to change { Security::Category.count }.by(1)
    end

    it 'responds with a successful service response' do
      expect(execute).to be_success
    end

    it 'has the expected attributes' do
      category = execute.payload[:category]

      expect(category.name).to eq(params[:name])
      expect(category.description).to eq(params[:description])
      expect(category.namespace).to eq(namespace)
      expect(category.template_type).to be_nil
      expect(category.multiple_selection).to be true
      expect(category.editable_state).to eq('editable')
    end

    it 'calls CreatePredefinedService with the correct parameters' do
      expect_next_instance_of(Security::Categories::CreatePredefinedService) do |instance|
        expect(instance).to receive(:execute).and_return(ServiceResponse.success)
      end

      execute
    end

    it 'creates an audit event' do
      expect { execute }.to change { AuditEvent.count }.by(1)

      audit_event = AuditEvent.last
      expect(audit_event.details).to include(
        event_name: 'security_category_created',
        author_name: current_user.name,
        custom_message: "Created security category #{params[:name]}",
        category_name: params[:name],
        category_description: params[:description],
        multiple_selection: params[:multiple_selection]
      )
    end
  end

  context 'when name already exists in the same namespace' do
    before do
      create(:security_category, namespace: namespace, name: params[:name])
    end

    let(:response) { execute }

    it 'responds with an error service response' do
      expect(response.success?).to be false
      expect(response.payload.messages[:name]).to include "has already been taken"
    end

    it 'does not create a duplicate category' do
      expect { execute }.not_to change { Security::Category.count }
    end
  end
end
