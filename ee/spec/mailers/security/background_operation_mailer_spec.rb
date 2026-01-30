# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::BackgroundOperationMailer, feature_category: :security_asset_inventories do
  let_it_be(:user) { build_stubbed(:user) }

  let(:operation) do
    {
      id: 'op_123',
      operation_type: 'attribute_update',
      total_items: 100,
      successful_items: 95,
      failed_items: 5
    }
  end

  let(:failed_items) do
    [
      {
        'project_id' => 1,
        'project_name' => 'My Project',
        'project_full_path' => 'my-group/my-project',
        'error_message' => 'Permission denied',
        'error_code' => 'permission_denied'
      },
      {
        'project_id' => 2,
        'project_name' => 'Another Project',
        'project_full_path' => 'my-group/another-project',
        'error_message' => 'Feature not enabled',
        'error_code' => 'feature_disabled'
      }
    ]
  end

  describe '#failure_notification' do
    subject(:mail) do
      described_class.failure_notification(
        user: user,
        operation: operation,
        failed_items: failed_items
      )
    end

    it 'sends email to user' do
      expect(mail.to).to eq([user.email])
    end

    it 'includes operation type in subject' do
      expect(mail.subject).to include('Attribute update')
    end

    it 'includes summary in body' do
      expect(mail.body.encoded).to include('100')
      expect(mail.body.encoded).to include('95')
      expect(mail.body.encoded).to include('5')
    end

    it 'includes failed items with project names in body' do
      expect(mail.body.encoded).to include('My Project')
      expect(mail.body.encoded).to include('Another Project')
      expect(mail.body.encoded).to include('Permission denied')
      expect(mail.body.encoded).to include('Feature not enabled')
    end
  end
end
