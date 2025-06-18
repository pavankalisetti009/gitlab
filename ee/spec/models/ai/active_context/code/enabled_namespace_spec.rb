# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ActiveContext::Code::EnabledNamespace, feature_category: :global_search do
  include LooseForeignKeysHelper

  let_it_be(:namespace) { create(:group) }
  let_it_be(:connection) { create(:ai_active_context_connection, :inactive) }

  describe 'validations' do
    subject(:enabled_namespace) do
      create(:ai_active_context_code_enabled_namespace, connection_id: connection.id, namespace: namespace)
    end

    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:active_context_connection) }
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_uniqueness_of(:connection_id).scoped_to(:namespace_id) }

    describe 'metadata' do
      it 'is valid for empty hash' do
        enabled_namespace.metadata = {}
        expect(enabled_namespace).to be_valid
      end

      it 'is invalid for a random hash' do
        enabled_namespace.metadata = { key: 'value' }
        expect(enabled_namespace).not_to be_valid
      end
    end

    describe '#valid_namespace' do
      let_it_be(:subgroup) { create(:group, parent: namespace) }
      let_it_be(:project_namespace) { create(:project_namespace) }

      it 'is valid for root group namespace' do
        enabled_namespace = build(:ai_active_context_code_enabled_namespace, namespace: namespace,
          connection_id: connection.id)

        expect(enabled_namespace).to be_valid
      end

      it 'is invalid for subgroup namespace' do
        enabled_namespace = build(:ai_active_context_code_enabled_namespace, namespace: subgroup,
          connection_id: connection.id)

        expect(enabled_namespace).not_to be_valid
        expect(enabled_namespace.errors[:namespace]).to include('must be a root group.')
      end

      it 'is invalid for project namespace' do
        enabled_namespace = build(:ai_active_context_code_enabled_namespace, namespace: project_namespace,
          connection_id: connection.id)

        expect(enabled_namespace).not_to be_valid
        expect(enabled_namespace.errors[:namespace]).to include('must be a root group.')
      end
    end
  end

  describe 'foreign key constraints' do
    it_behaves_like 'it has loose foreign keys' do
      let(:factory_name) { :ai_active_context_code_enabled_namespace }
    end

    describe 'when namespace is deleted' do
      let_it_be(:enabled_namespace) { create(:ai_active_context_code_enabled_namespace, namespace: namespace) }

      it 'deletes the enabled_namespace' do
        expect(enabled_namespace.namespace_id).to eq(namespace.id)

        namespace.destroy!

        expect { enabled_namespace.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'when connection is deleted' do
      it_behaves_like 'cleanup by a loose foreign key' do
        let!(:model) do
          create(:ai_active_context_code_enabled_namespace, connection_id: connection.id, namespace: namespace)
        end

        let!(:parent) { connection }
      end
    end
  end
end
