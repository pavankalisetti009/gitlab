# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::MarkForDeletionService, feature_category: :groups_and_projects do
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  subject(:execute) { described_class.new(group, user, {}).execute }

  before do
    stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
  end

  context 'when marking the group for deletion' do
    context 'with user that can admin the group' do
      before do
        group.add_owner(user)
      end

      context 'for a group that has not been marked for deletion' do
        it 'marks the group for deletion', :freeze_time do
          execute

          expect(group.marked_for_deletion_on).to eq(Time.zone.today)
          expect(group.deleting_user).to eq(user)
        end

        it 'returns success' do
          expect(execute).to eq({ status: :success })
        end

        describe 'group deletion notification' do
          context 'when group_deletion_notification_email feature flag is enabled' do
            context 'when adjourned deletion is enabled' do
              it 'sends notification email' do
                expect_next_instance_of(NotificationService) do |service|
                  expect(service).to receive(:group_scheduled_for_deletion).with(group)
                end

                execute
              end
            end

            context 'when adjourned deletion is disabled' do
              before do
                allow(group).to receive(:adjourned_deletion?).and_return(false)
              end

              it 'does not send notification email' do
                expect(NotificationService).not_to receive(:new)

                execute
              end
            end

            context 'when feature flag is enabled for specific group' do
              before do
                stub_feature_flags(group_deletion_notification_email: group)
              end

              it 'sends notification email' do
                expect_next_instance_of(NotificationService) do |service|
                  expect(service).to receive(:group_scheduled_for_deletion).with(group)
                end

                execute
              end
            end
          end

          context 'when group_deletion_notification_email feature flag is disabled' do
            before do
              stub_feature_flags(group_deletion_notification_email: false)
            end

            it 'does not send notification email' do
              expect(NotificationService).not_to receive(:new)

              execute
            end
          end
        end

        context 'when marking for deletion fails' do
          before do
            expect_next_instance_of(GroupDeletionSchedule) do |group_deletion_schedule|
              allow(group_deletion_schedule).to receive_message_chain(:errors, :full_messages)
                .and_return(['error message'])

              allow(group_deletion_schedule).to receive(:save).and_return(false)
            end
          end

          it 'returns error' do
            expect(execute).to eq({ status: :error, message: 'error message' })
          end
        end
      end

      context 'for a group that has been marked for deletion' do
        let(:deletion_date) { 3.days.ago }
        let(:group) do
          create(:group_with_deletion_schedule,
            marked_for_deletion_on: deletion_date,
            deleting_user: user)
        end

        it 'does not change the attributes associated with delayed deletion' do
          execute

          expect(group.marked_for_deletion_on).to eq(deletion_date.to_date)
          expect(group.deleting_user).to eq(user)
        end

        it 'returns error' do
          expect(execute).to eq({ status: :error, message: 'Group has been already marked for deletion' })
        end

        it 'does not send notification email again' do
          expect(NotificationService).not_to receive(:new)

          execute
        end
      end

      context 'for audit events' do
        it 'logs audit event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(name: 'group_deletion_marked')
          ).and_call_original

          expect { execute }.to change { AuditEvent.count }.by(1)
        end
      end
    end

    context 'with a user that cannot admin the group' do
      it 'does not mark the group for deletion' do
        execute

        expect(group.marked_for_deletion?).to be_falsey
      end

      it 'returns error' do
        expect(execute).to eq({ status: :error, message: 'You are not authorized to perform this action' })
      end

      it 'does not send notification email' do
        expect(NotificationService).not_to receive(:new)

        execute
      end

      context 'for audit events' do
        it 'does not log audit event' do
          expect { execute }.not_to change { AuditEvent.count }
        end
      end
    end
  end
end
