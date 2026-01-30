# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundOperations::RedisStore, feature_category: :security_asset_inventories do
  let(:operation_type) { 'attribute_update' }
  let(:user_id) { 1 }
  let(:total_items) { 10 }
  let(:parameters) { { 'attribute_ids' => [1, 2], 'mode' => 'ADD' } }
  let(:created_operation_ids) { [] }
  let(:operation_id) { create_test_operation }

  after do
    created_operation_ids.each { |id| described_class.delete_operation(id) }
  end

  def create_test_operation(**args)
    defaults = {
      operation_type: operation_type,
      user_id: user_id,
      total_items: total_items,
      parameters: parameters
    }
    described_class.create_operation(**defaults.merge(args)).tap { |id| created_operation_ids << id }
  end

  describe '.create_operation' do
    it 'creates operation in Redis with all fields and returns operation_id' do
      op_id = create_test_operation

      expect(op_id).to match(/^attribute_update_1_\d+_[a-f0-9]+$/)

      operation = described_class.get_operation(op_id)

      expect(operation).to have_attributes(
        id: op_id,
        operation_type: operation_type,
        user_id: user_id,
        parameters: parameters,
        total_items: total_items,
        successful_items: 0,
        failed_items: 0
      )
    end

    it 'defaults parameters to empty hash' do
      op_id = create_test_operation(parameters: {})

      operation = described_class.get_operation(op_id)

      expect(operation.parameters).to eq({})
    end
  end

  describe '.increment_successful' do
    it 'increments successful items' do
      described_class.increment_successful(operation_id, 5)

      operation = described_class.get_operation(operation_id)
      expect(operation.successful_items).to eq(5)
    end

    it 'increments by 1 by default' do
      described_class.increment_successful(operation_id)

      operation = described_class.get_operation(operation_id)
      expect(operation.successful_items).to eq(1)
    end
  end

  describe '.add_failed_project' do
    it 'adds failed project and increments counter atomically' do
      described_class.add_failed_project(
        operation_id,
        project_id: 10,
        project_name: 'My Project',
        project_full_path: 'my-group/my-project',
        error_message: 'Permission denied',
        error_code: 'permission_denied'
      )

      operation = described_class.get_operation(operation_id)
      expect(operation.failed_items).to eq(1)

      items = described_class.get_failed_items(operation_id)
      expect(items.size).to eq(1)
      expect(items.first['project_id']).to eq(10)
      expect(items.first['project_name']).to eq('My Project')
      expect(items.first['project_full_path']).to eq('my-group/my-project')
      expect(items.first['error_message']).to eq('Permission denied')
      expect(items.first['error_code']).to eq('permission_denied')
    end

    it 'adds multiple failed projects' do
      described_class.add_failed_project(
        operation_id,
        project_id: 10,
        error_message: 'Error 1',
        error_code: 'code_1'
      )
      described_class.add_failed_project(
        operation_id,
        project_id: 20,
        error_message: 'Error 2',
        error_code: 'code_2'
      )

      operation = described_class.get_operation(operation_id)
      expect(operation.failed_items).to eq(2)

      items = described_class.get_failed_items(operation_id)
      expect(items.size).to eq(2)
    end

    it 'does not add duplicate failures for the same project_id' do
      described_class.add_failed_project(
        operation_id,
        project_id: 10,
        error_message: 'First error',
        error_code: 'code_1'
      )
      described_class.add_failed_project(
        operation_id,
        project_id: 10,
        error_message: 'Second error',
        error_code: 'code_2'
      )

      operation = described_class.get_operation(operation_id)
      expect(operation.failed_items).to eq(1)

      items = described_class.get_failed_items(operation_id)
      expect(items.size).to eq(1)
      expect(items.first['error_message']).to eq('First error')
    end
  end

  describe '.get_operation' do
    it 'returns nil if operation does not exist' do
      operation = described_class.get_operation('nonexistent')

      expect(operation).to be_nil
    end

    it 'returns operation as struct' do
      operation = described_class.get_operation(operation_id)

      expect(operation).to be_a(described_class::Operation)
      expect(operation.id).to eq(operation_id)
      expect(operation.parameters).to eq(parameters)
    end
  end

  describe '.get_failed_items' do
    it 'returns empty array if no failed items' do
      items = described_class.get_failed_items(operation_id)

      expect(items).to eq([])
    end

    it 'returns all failed items' do
      3.times do |i|
        described_class.add_failed_project(
          operation_id,
          project_id: i,
          error_message: "Error #{i}",
          error_code: "code_#{i}"
        )
      end

      items = described_class.get_failed_items(operation_id)

      expect(items.size).to eq(3)
    end
  end

  describe '.delete_operation' do
    it 'deletes operation and failed items' do
      described_class.add_failed_project(
        operation_id,
        project_id: 10,
        error_message: 'Error',
        error_code: 'code'
      )

      described_class.delete_operation(operation_id)

      operation = described_class.get_operation(operation_id)
      items = described_class.get_failed_items(operation_id)

      expect(operation).to be_nil
      expect(items).to eq([])
    end
  end
end
