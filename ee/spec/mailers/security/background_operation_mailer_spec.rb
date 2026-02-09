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
        'entity_id' => 1,
        'entity_type' => 'Project',
        'entity_name' => 'My Project',
        'entity_full_path' => 'my-group/my-project',
        'error_message' => 'Permission denied'
      },
      {
        'entity_id' => 2,
        'entity_type' => 'Project',
        'entity_name' => 'Another Project',
        'entity_full_path' => 'my-group/another-project',
        'error_message' => 'Feature not enabled'
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

    context 'with unknown operation type' do
      let(:operation) do
        {
          id: 'op_123',
          operation_type: 'unknown_operation',
          total_items: 100,
          successful_items: 95,
          failed_items: 5
        }
      end

      it 'humanizes unknown operation type in subject' do
        expect(mail.subject).to include('unknown operation')
      end
    end

    it 'includes summary in body' do
      expect(mail.body.encoded).to include('100')
      expect(mail.body.encoded).to include('95')
      expect(mail.body.encoded).to include('5')
    end

    it 'includes failed items with entity names in body' do
      expect(mail.body.encoded).to include('My Project')
      expect(mail.body.encoded).to include('Another Project')
      expect(mail.body.encoded).to include('Permission denied')
      expect(mail.body.encoded).to include('Feature not enabled')
    end

    context 'when error_message is an array with project references' do
      let(:failed_items) do
        [
          {
            'entity_id' => 22,
            'entity_type' => 'Group',
            'entity_name' => 'Toolbox',
            'entity_full_path' => 'toolbox',
            'error_message' => [
              "Project 'Security Reports 2' (toolbox/security-reports-2) has reached the maximum limit",
              "Project 'Security Reports' (toolbox/subgroup-2/security-reports) has reached the maximum limit"
            ]
          }
        ]
      end

      it 'includes all error messages in body' do
        expect(mail.body.encoded).to include('Toolbox')
        expect(mail.body.encoded).to include('Security Reports 2')
        expect(mail.body.encoded).to include('Security Reports')
      end

      it 'converts project references to clickable links' do
        body = mail.body.encoded

        expect(body).to include('href="http://localhost/toolbox/security-reports-2"')
        expect(body).to include('href="http://localhost/toolbox/subgroup-2/security-reports"')
        expect(body).to include('>Security Reports 2</a>')
        expect(body).to include('>Security Reports</a>')
      end
    end
  end

  describe '#linkify_project_references' do
    subject(:mailer) { described_class.new }

    it 'converts project references to links' do
      message = "Project 'My Project' (group/my-project) has reached the maximum limit"

      result = mailer.linkify_project_references(message)

      expect(result).to include('href="http://localhost/group/my-project"')
      expect(result).to include('>My Project</a>')
      expect(result).to include('has reached the maximum limit')
    end

    it 'handles multiple project references in one message' do
      message = "Project 'Proj A' (group/proj-a) and Project 'Proj B' (group/proj-b) failed."

      result = mailer.linkify_project_references(message)

      expect(result).to include('href="http://localhost/group/proj-a"')
      expect(result).to include('href="http://localhost/group/proj-b"')
      expect(result).to include('>Proj A</a>')
      expect(result).to include('>Proj B</a>')
    end

    it 'returns original message when no project references found' do
      message = "Permission denied for this operation."

      result = mailer.linkify_project_references(message)

      expect(result).to eq(message)
    end

    it 'handles project names with special characters' do
      message = "Project 'My Project (v2.0)' (group/my-project-v2) has an error."

      result = mailer.linkify_project_references(message)

      expect(result).to include('href="http://localhost/group/my-project-v2"')
      expect(result).to include('>My Project (v2.0)</a>')
    end
  end
end
