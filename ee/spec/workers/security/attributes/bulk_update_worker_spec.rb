# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::BulkUpdateWorker, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: namespace) }
  let_it_be(:project2) { create(:project, namespace: namespace) }
  let_it_be(:root_namespace) { namespace.root_ancestor }

  let_it_be(:category) { create(:security_category, namespace: root_namespace, name: 'Test Category') }
  let_it_be(:attribute1) do
    create(:security_attribute, security_category: category, name: 'Critical', namespace: root_namespace)
  end

  let_it_be(:attribute2) do
    create(:security_attribute, security_category: category, name: 'High', namespace: root_namespace)
  end

  let(:project_ids) { [project1.id, project2.id] }
  let(:attribute_ids) { [attribute1.id, attribute2.id] }
  let(:mode) { 'add' }
  let(:user_id) { user.id }

  subject(:worker) { described_class.new }

  describe '#perform' do
    before_all do
      namespace.add_maintainer(user)
      stub_feature_flags(security_categories_and_attributes: true)
    end

    context 'when user exists' do
      it 'processes all projects' do
        expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new).twice.and_call_original

        worker.perform(project_ids, attribute_ids, mode, user_id)
      end

      it 'calls UpdateProjectAttributesService with correct parameters for ADD mode' do
        expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
          .with(
            project: project1,
            current_user: user,
            params: {
              attributes: {
                add_attribute_ids: attribute_ids,
                remove_attribute_ids: []
              }
            }
          )
          .and_call_original

        expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
          .with(
            project: project2,
            current_user: user,
            params: {
              attributes: {
                add_attribute_ids: attribute_ids,
                remove_attribute_ids: []
              }
            }
          )
          .and_call_original

        worker.perform(project_ids, attribute_ids, mode, user_id)
      end

      context 'with REMOVE mode' do
        let(:mode) { 'remove' }

        it 'calls UpdateProjectAttributesService with correct parameters for REMOVE mode' do
          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(
              project: project1,
              current_user: user,
              params: {
                attributes: {
                  add_attribute_ids: [],
                  remove_attribute_ids: attribute_ids
                }
              }
            )
            .and_call_original

          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(
              project: project2,
              current_user: user,
              params: {
                attributes: {
                  add_attribute_ids: [],
                  remove_attribute_ids: attribute_ids
                }
              }
            )
            .and_call_original

          worker.perform(project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'when feature flag is disabled for a project' do
        before do
          stub_feature_flags(security_categories_and_attributes: false)
        end

        it 'skips processing projects without feature flag' do
          expect(Security::Attributes::UpdateProjectAttributesService).not_to receive(:new)

          worker.perform(project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'when user lacks permissions for a project' do
        let_it_be(:unauthorized_project) { create(:project) }
        let(:project_ids) { [project1.id, unauthorized_project.id] }

        it 'skips unauthorized projects' do
          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(hash_including(project: project1))
            .and_call_original

          expect(Security::Attributes::UpdateProjectAttributesService).not_to receive(:new)
            .with(hash_including(project: unauthorized_project))

          worker.perform(project_ids, attribute_ids, mode, user_id)
        end
      end

      context 'when service raises an error' do
        before do
          allow_next_instance_of(Security::Attributes::UpdateProjectAttributesService) do |service|
            allow(service).to receive(:execute).and_raise(StandardError, 'Service error')
          end
        end

        it 'tracks the exception and continues processing' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(
              an_instance_of(StandardError),
              {
                project_id: project1.id,
                attribute_ids: attribute_ids,
                mode: mode,
                user_id: user_id
              }
            )

          expect(Gitlab::ErrorTracking).to receive(:track_exception)
            .with(
              an_instance_of(StandardError),
              {
                project_id: project2.id,
                attribute_ids: attribute_ids,
                mode: mode,
                user_id: user_id
              }
            )

          expect { worker.perform(project_ids, attribute_ids, mode, user_id) }.not_to raise_error
        end
      end

      context 'when project does not exist' do
        let(:project_ids) { [project1.id, non_existing_record_id] }

        it 'processes only existing projects' do
          expect(Security::Attributes::UpdateProjectAttributesService).to receive(:new)
            .with(hash_including(project: project1))
            .and_call_original

          worker.perform(project_ids, attribute_ids, mode, user_id)
        end
      end
    end

    context 'when user does not exist' do
      let(:user_id) { non_existing_record_id }

      it 'returns early without processing' do
        expect(Security::Attributes::UpdateProjectAttributesService).not_to receive(:new)

        worker.perform(project_ids, attribute_ids, mode, user_id)
      end
    end

    context 'with invalid mode' do
      let(:mode) { 'invalid' }

      it 'tracks the exception and continues processing' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(
            an_instance_of(ArgumentError),
            hash_including(mode: mode)
          ).at_least(:once)

        expect { worker.perform(project_ids, attribute_ids, mode, user_id) }.not_to raise_error
      end
    end
  end
end
