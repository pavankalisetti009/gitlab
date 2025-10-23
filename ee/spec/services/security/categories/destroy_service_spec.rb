# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Categories::DestroyService, feature_category: :security_asset_inventories do
  shared_examples 'successful category deletion' do
    it 'deletes the category successfully and returns its global ID' do
      attributes = test_category.security_attributes
      expected_data = {
        category_gid: test_category.to_global_id,
        attributes_gid: attributes.map(&:to_global_id),
        attribute_ids: attributes.map(&:id)
      }

      result = described_class.new(
        category: test_category,
        current_user: user
      ).execute

      # Verify the service succeeded
      expect(result).to be_success
      expect(result.payload[:deleted_category_gid]).to eq(expected_data[:category_gid])

      if expected_data[:attributes_gid].any?
        expect(result.payload[:deleted_attributes_gid]).to match_array(expected_data[:attributes_gid])
      end

      # Verify category is deleted
      expect(Security::Category.find_by(id: test_category.id)).to be_nil

      # Verify attributes are actually deleted (CASCADE should handle this)
      expected_data[:attribute_ids].each do |attribute_id|
        expect(Security::Attribute.find_by(id: attribute_id)).to be_nil
      end
    end
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:category) do
    create(:security_category, namespace: namespace, editable_state: :editable)
  end

  let_it_be_with_reload(:editable_attribute) do
    create(:security_attribute,
      security_category: category,
      namespace: namespace,
      editable_state: :editable,
      name: 'Editable Attribute')
  end

  subject(:execute) do
    described_class.new(
      category: category,
      current_user: user
    ).execute
  end

  describe '#execute' do
    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(security_categories_and_attributes: false)
      end

      it 'raises an access denied error' do
        expect { execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(security_categories_and_attributes: true)
      end

      context 'when user does not have permission' do
        it 'returns an unauthorized error' do
          expect { execute }.not_to change { Security::Category.count }

          expect(execute).to be_error
          expect(execute.message).to eq('You are not authorized to perform this action')
        end
      end

      context 'when user has permission' do
        before_all do
          namespace.add_owner(user)
        end

        context 'when category is not editable' do
          before do
            category.update!(editable_state: :locked)
          end

          it 'returns an error and does not delete the category' do
            expect { execute }.not_to change { Security::Category.count }

            expect(execute).to be_error
            expect(execute.message).to eq('Cannot delete non-editable category')
          end

          it 'does not delete associated attributes' do
            expect { execute }.not_to change { Security::Attribute.count }
          end
        end

        context 'when category is editable' do
          let(:test_category) { category }

          include_examples 'successful category deletion'

          it 'creates an audit event' do
            expect { execute }.to change { AuditEvent.count }.by(1)

            audit_event = AuditEvent.last

            expect(audit_event.details).to include(
              event_name: 'security_category_deleted',
              author_name: user.name,
              custom_message: "Deleted security category #{category.name}",
              category_name: category.name,
              category_description: category.description,
              attributes_count: 1
            )
          end
        end

        context 'when deletion fails due to database error' do
          before_all do
            namespace.add_owner(user)
          end
          before do
            allow(category).to receive(:destroy).and_raise(
              ActiveRecord::StatementInvalid.new('Database constraint violation')
            )
          end

          it 'returns an error with the failure message' do
            expect { execute }.not_to change { Security::Category.count }

            expect(execute).to be_error
            expect(execute.message).to eq('Failed to delete category: Database constraint violation')
          end
        end

        context 'with different category types' do
          let_it_be_with_reload(:locked_category) do
            create(:security_category,
              namespace: namespace,
              editable_state: :locked,
              name: 'Locked Category')
          end

          before_all do
            namespace.add_owner(user)
          end

          context 'when category has locked state' do
            it 'returns an error and does not delete the category' do
              result = described_class.new(
                category: locked_category,
                current_user: user
              ).execute

              expect(result).to be_error
              expect(result.message).to eq('Cannot delete non-editable category')
            end
          end
        end

        context 'when category has multiple attributes' do
          let_it_be_with_reload(:multi_attr_category) do
            create(:security_category, namespace: namespace, editable_state: :editable,
              name: 'Multi Attribute Category')
          end

          let(:test_category) { multi_attr_category }

          let_it_be_with_reload(:first_attribute) do
            create(:security_attribute,
              security_category: multi_attr_category,
              namespace: namespace,
              editable_state: :editable)
          end

          let_it_be_with_reload(:second_attribute) do
            create(:security_attribute,
              security_category: multi_attr_category,
              namespace: namespace,
              editable_state: :editable)
          end

          before_all do
            namespace.add_owner(user)
          end

          include_examples 'successful category deletion'
        end

        context 'when category has no attributes' do
          let_it_be_with_reload(:empty_category) do
            create(:security_category, namespace: namespace, editable_state: :editable, name: 'Empty Category')
          end

          let(:test_category) { empty_category }

          include_examples 'successful category deletion'
        end

        context 'when cleaning up project associations' do
          let_it_be_with_reload(:cleanup_category) do
            create(:security_category, namespace: namespace, editable_state: :editable, name: 'Cleanup Category')
          end

          let_it_be_with_reload(:attr_with_projects) do
            create(:security_attribute,
              security_category: cleanup_category,
              namespace: namespace,
              editable_state: :editable,
              name: 'Cleanup Attribute')
          end

          before_all do
            namespace.add_owner(user)
          end

          it 'enqueues cleanup worker with correct attribute IDs' do
            expect(Security::Attributes::CleanupProjectToSecurityAttributeWorker)
              .to receive(:perform_async)
              .with([attr_with_projects.id])

            described_class.new(
              category: cleanup_category,
              current_user: user
            ).execute
          end

          it 'enqueues cleanup worker for multiple attributes' do
            second_attr = create(:security_attribute,
              security_category: cleanup_category,
              namespace: namespace,
              editable_state: :editable,
              name: 'Second Cleanup Attribute')

            expect(Security::Attributes::CleanupProjectToSecurityAttributeWorker)
              .to receive(:perform_async)
              .with(match_array([attr_with_projects.id, second_attr.id]))

            described_class.new(
              category: cleanup_category,
              current_user: user
            ).execute
          end

          it 'does not enqueue cleanup worker when deletion fails' do
            allow(cleanup_category).to receive(:destroy).and_raise(
              ActiveRecord::RecordNotDestroyed.new('Deletion failed')
            )

            expect(Security::Attributes::CleanupProjectToSecurityAttributeWorker)
              .not_to receive(:perform_async)

            described_class.new(
              category: cleanup_category,
              current_user: user
            ).execute
          end
        end
      end
    end
  end
end
