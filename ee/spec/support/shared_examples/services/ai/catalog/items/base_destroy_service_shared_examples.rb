# frozen_string_literal: true

RSpec.shared_examples Ai::Catalog::Items::BaseDestroyService do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:params) { { item: item } }
  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  describe '#execute' do
    subject(:execute_service) { service.execute }

    shared_examples 'returns item not found error' do
      it 'returns item not found error' do
        result = execute_service

        expect(result).to be_error
        expect(result.errors).to contain_exactly(not_found_error)
      end

      it 'does not destroy any items' do
        expect { execute_service }.not_to change { Ai::Catalog::Item.count }
      end
    end

    context 'when item is invalid' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when item is nil' do
        let(:params) { { item: nil } }

        it_behaves_like 'returns item not found error'
      end
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when item exists' do
        shared_examples 'hard deletes the item' do
          it 'destroys the item successfully' do
            expect { execute_service }.to change { Ai::Catalog::Item.count }.by(-1)
          end

          it 'destroys item versions' do
            expect { execute_service }.to change { Ai::Catalog::ItemVersion.count }.by(-1)
          end

          it 'triggers delete_ai_catalog_item', :clean_gitlab_redis_shared_state do
            expect { execute_service }
              .to trigger_internal_events('delete_ai_catalog_item')
              .with(user: user, project: project, additional_properties: { label: item.item_type })
              .and increment_usage_metrics('counts.count_total_delete_ai_catalog_item')
          end

          it 'returns success response' do
            result = execute_service

            expect(result.success?).to be(true)
          end
        end

        shared_examples 'soft deletes the item' do
          it 'soft deletes the item' do
            expect { execute_service }.to change { item.deleted_at }.from(nil)
          end

          it 'does not destroy the item' do
            expect { execute_service }.not_to change { Ai::Catalog::Item.count }
          end

          it 'does not destroy item versions' do
            expect { execute_service }.not_to change { Ai::Catalog::ItemVersion.count }
          end

          it 'triggers delete_ai_catalog_item', :clean_gitlab_redis_shared_state do
            expect { execute_service }
              .to trigger_internal_events('delete_ai_catalog_item')
              .with(user: user, project: project, additional_properties: { label: item.item_type })
          end

          it 'returns success response' do
            result = execute_service

            expect(result.success?).to be(true)
          end
        end

        it_behaves_like 'hard deletes the item'

        context 'when item is only being used by the project' do
          before do
            create(:ai_catalog_item_consumer, item: item, project: project)
          end

          it_behaves_like 'hard deletes the item'
        end

        context 'when item is being used by other projects' do
          before do
            create(:ai_catalog_item_consumer, item: item, project: create(:project))
          end

          it_behaves_like 'soft deletes the item'
        end

        context 'when item is being used by both the project and another project' do
          let_it_be(:other_project) { create(:project) }

          before do
            create(:ai_catalog_item_consumer, item: item, project: other_project)
            create(:ai_catalog_item_consumer, item: item, project: project)
          end

          it "deletes just the project's consumer record, and soft deletes the item" do
            expect { execute_service }.to change { item.deleted_at }.from(nil)

            expect(other_project.configured_ai_catalog_items.size).to eq(1)
            expect(project.configured_ai_catalog_items).to be_empty
          end
        end

        context 'when an error happens when deleting the consumer' do
          before do
            create(:ai_catalog_item_consumer, item: item, project: project)

            allow_next_instance_of(Ai::Catalog::ItemConsumers::DestroyService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Failure'))
            end
          end

          it 'does not destroy the item' do
            expect { execute_service }.not_to change { Ai::Catalog::Item.count }
          end

          it 'returns error response' do
            result = execute_service

            expect(result).to be_error
            expect(result.errors).to contain_exactly('Failure')
          end
        end

        context 'when item is a dependency of other items (has item_version_dependency)' do
          before do
            create(:ai_catalog_item_version_dependency, dependency_id: item.id)
          end

          it_behaves_like 'soft deletes the item'
        end
      end

      context 'when item destruction fails' do
        before do
          allow(item).to receive(:destroy).and_return(false)
          item.errors.add(:base, 'Item cannot be destroyed')
        end

        it 'does not destroy the item' do
          expect { execute_service }.not_to change { Ai::Catalog::Item.count }
        end

        it 'returns error response' do
          result = execute_service

          expect(result).to be_error
          expect(result.errors).to contain_exactly('Item cannot be destroyed')
        end
      end
    end

    context 'when user lacks permissions' do
      before_all do
        project.add_developer(user)
      end

      it 'returns permission error' do
        result = execute_service

        expect(result).to be_error
        expect(result.errors).to contain_exactly('You have insufficient permissions')
      end

      it 'does not destroy the item' do
        expect { execute_service }.not_to change { Ai::Catalog::Item.count }
      end
    end

    if described_class < Ai::Catalog::Items::BaseDestroyService
      context 'when catalog item is the wrong type' do
        let_it_be(:item) { incorrect_item_type }

        before_all do
          project.add_maintainer(user)
        end

        it 'returns not found error' do
          result = execute_service

          expect(result).to be_error
          expect(result.errors).to contain_exactly(not_found_error)
        end

        it 'does not destroy any items' do
          expect { execute_service }.not_to change { Ai::Catalog::Item.count }
        end

        it 'does not destroy any item versions' do
          expect { execute_service }.not_to change { Ai::Catalog::ItemVersion.count }
        end

        it 'does not trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
          expect { execute_service }
            .not_to trigger_internal_events('delete_ai_catalog_item')
        end
      end
    end
  end
end
