#  frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Lifecycles::UpdateService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let(:user) { create(:user, maintainer_of: group) }
  let_it_be(:system_defined_lifecycle) { WorkItems::Statuses::SystemDefined::Lifecycle.all.first }

  let(:params) do
    {
      id: system_defined_lifecycle.to_gid,
      statuses: [
        status_params_for(system_defined_lifecycle.default_open_status),
        status_params_for(system_defined_lifecycle.default_closed_status),
        status_params_for(system_defined_lifecycle.default_duplicate_status)
      ],
      default_open_status_index: 0,
      default_closed_status_index: 1,
      default_duplicate_status_index: 2
    }
  end

  subject(:result) do
    described_class.new(container: group, current_user: user, params: params).execute
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  describe '#execute' do
    let(:lifecycle) { result.payload[:lifecycle] }

    context 'when custom lifecycle does not exist' do
      it 'creates a custom lifecycle' do
        expect { result }.to change { WorkItems::Statuses::Custom::Lifecycle.count }.by(1)

        expect(lifecycle).to have_attributes(
          name: 'Default',
          namespace: group,
          created_by: user
        )
      end

      it 'creates custom statuses from system-defined statuses' do
        expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(3)

        expect(lifecycle.statuses.pluck(:name)).to contain_exactly(
          system_defined_lifecycle.default_open_status.name,
          system_defined_lifecycle.default_closed_status.name,
          system_defined_lifecycle.default_duplicate_status.name
        )
        expect(lifecycle.statuses.count).to eq(3)
      end

      it 'sets default statuses correctly' do
        expect(lifecycle.default_open_status.name).to eq(system_defined_lifecycle.default_open_status.name)
        expect(lifecycle.default_closed_status.name).to eq(system_defined_lifecycle.default_closed_status.name)
        expect(lifecycle.default_duplicate_status.name).to eq(system_defined_lifecycle.default_duplicate_status.name)
      end
    end

    context 'when custom lifecycle exists' do
      let!(:custom_lifecycle) do
        create(:work_item_custom_lifecycle, name: system_defined_lifecycle.name, namespace: group)
      end

      context 'when system-defined lifecycle is provided' do
        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Invalid lifecycle type. Custom lifecycle already exists.')
        end
      end

      context 'when custom lifecycle is provided' do
        let(:params) do
          {
            id: custom_lifecycle.to_gid,
            statuses: [
              status_params_for(custom_lifecycle.default_open_status),
              status_params_for(custom_lifecycle.default_closed_status),
              status_params_for(custom_lifecycle.default_duplicate_status),
              {
                name: 'Ready for development',
                color: '#737278',
                description: nil,
                category: 'to_do'
              },
              {
                name: 'Complete',
                color: '#108548',
                description: nil,
                category: 'done'
              }
            ],
            default_open_status_index: 0,
            default_closed_status_index: 1,
            default_duplicate_status_index: 2
          }
        end

        context 'when statuses are added' do
          it 'adds custom statuses' do
            expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(2)

            expect(lifecycle.statuses.pluck(:name)).to include('Ready for development', 'Complete')

            expect(lifecycle.statuses.count).to eq(5)
          end

          it 'reorders statuses correctly' do
            expect(lifecycle.ordered_statuses.pluck(:name)).to eq([
              custom_lifecycle.default_open_status.name,
              'Ready for development',
              custom_lifecycle.default_closed_status.name,
              'Complete',
              custom_lifecycle.default_duplicate_status.name
            ])
          end
        end

        context 'when statuses are updated' do
          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                status_params_for(custom_lifecycle.default_open_status).merge(
                  name: 'Updated To Do',
                  description: 'Updated description'
                ),
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 1,
              default_duplicate_status_index: 2
            }
          end

          it 'updates custom status attributes' do
            expect(lifecycle.default_open_status).to have_attributes(
              name: 'Updated To Do',
              description: 'Updated description',
              updated_by: user
            )
          end

          context 'when updating status without providing ID' do
            let(:params) do
              {
                id: custom_lifecycle.to_gid,
                statuses: [
                  {
                    name: custom_lifecycle.default_open_status.name,
                    color: custom_lifecycle.default_open_status.color,
                    description: 'Updated description',
                    category: custom_lifecycle.default_open_status.category
                  },
                  status_params_for(custom_lifecycle.default_closed_status),
                  status_params_for(custom_lifecycle.default_duplicate_status)
                ],
                default_open_status_index: 0,
                default_closed_status_index: 1,
                default_duplicate_status_index: 2
              }
            end

            it 'updates custom status attributes' do
              expect(lifecycle.default_open_status).to have_attributes(
                description: 'Updated description',
                updated_by: user
              )
            end
          end
        end

        context 'when default statuses are updated' do
          let(:new_open_status) { create(:work_item_custom_status, namespace: group) }
          let!(:new_open_lifecycle_status) do
            create(:work_item_custom_lifecycle_status,
              lifecycle: custom_lifecycle, status: new_open_status, namespace: group)
          end

          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                status_params_for(new_open_status),
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 1,
              default_duplicate_status_index: 2
            }
          end

          it 'updates the default status' do
            expect(lifecycle.default_open_status).to eq(new_open_status)
            expect(lifecycle.updated_by).to eq(user)
          end
        end

        context 'when statuses are removed' do
          let(:custom_status) { create(:work_item_custom_status, name: 'Ready for development', namespace: group) }
          let!(:custom_lifecycle_status) do
            create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: custom_status,
              namespace: group)
          end

          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                status_params_for(custom_lifecycle.default_open_status),
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 1,
              default_duplicate_status_index: 2
            }
          end

          it 'removes custom statuses' do
            expect { result }.to change { WorkItems::Statuses::Custom::Status.count }.by(-1)

            expect(lifecycle.statuses.pluck(:name)).not_to include('Ready for development')

            expect(lifecycle.statuses.count).to eq(3)
          end

          it 'reorders statuses correctly' do
            expect(lifecycle.ordered_statuses.pluck(:name)).to eq([
              custom_lifecycle.default_open_status.name,
              custom_lifecycle.default_closed_status.name,
              custom_lifecycle.default_duplicate_status.name
            ])
          end

          context 'when trying to remove a status in use' do
            let(:work_item) { create(:work_item, namespace: group) }
            let!(:current_status) do
              create(:work_item_current_status, work_item: work_item, custom_status: custom_status)
            end

            it 'returns an error' do
              expect(result).to be_error
              expect(result.message).to eq("Cannot delete status '#{custom_status.name}' because it is in use")
              expect(custom_status.reload).to be_persisted
            end
          end

          context 'when trying to remove a default status' do
            let(:params) do
              {
                id: custom_lifecycle.to_gid.to_s,
                statuses: [
                  status_params_for(custom_lifecycle.default_open_status),
                  status_params_for(custom_lifecycle.default_closed_status)
                ]
              }
            end

            it 'returns an error' do
              expect(result).to be_error
              expect(result.message).to eq(
                "Cannot delete status '#{custom_lifecycle.default_duplicate_status.name}' " \
                  "because it is marked as a default status"
              )
            end
          end
        end

        context 'when statuses are reordered' do
          let(:existing_in_progress_status) do
            create(:work_item_custom_status, name: 'In Progress', namespace: group, category: :in_progress)
          end

          let!(:lifecycle_status) do
            create(:work_item_custom_lifecycle_status,
              lifecycle: custom_lifecycle, status: existing_in_progress_status, namespace: group)
          end

          let(:params) do
            {
              id: custom_lifecycle.to_gid,
              statuses: [
                {
                  name: 'Ready for development',
                  color: '#737278',
                  description: nil,
                  category: 'to_do'
                },
                status_params_for(existing_in_progress_status),
                {
                  name: 'Complete',
                  color: '#108548',
                  description: nil,
                  category: 'done'
                },
                status_params_for(custom_lifecycle.default_closed_status),
                status_params_for(custom_lifecycle.default_duplicate_status)
              ],
              default_open_status_index: 0,
              default_closed_status_index: 2,
              default_duplicate_status_index: 4
            }
          end

          it 'reorders statuses correctly' do
            expect(lifecycle.ordered_statuses.pluck(:name)).to eq([
              'Ready for development',
              'In Progress',
              'Complete',
              custom_lifecycle.default_closed_status.name,
              custom_lifecycle.default_duplicate_status.name
            ])
          end
        end
      end
    end

    context 'when work_item_status_feature_flag is disabled' do
      before do
        stub_feature_flags(work_item_status_feature_flag: false)
      end

      it 'returns feature not available error' do
        expect(result).to be_error
        expect(result.message).to eq('This feature is currently behind a feature flag, and it is not available.')
      end
    end

    context 'when user is not authorized' do
      let(:user) { create(:user, guest_of: group) }

      it 'returns authorization error' do
        expect(result).to be_error
        expect(result.message).to eq("You don't have permission to update a lifecycle for this namespace.")
      end
    end
  end

  private

  def status_params_for(status)
    {
      id: status.to_global_id,
      name: status.name,
      color: status.color,
      description: status.description,
      category: status.category
    }
  end
end
