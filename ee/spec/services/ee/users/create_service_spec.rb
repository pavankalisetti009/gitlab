# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::CreateService, feature_category: :user_management do
  let_it_be(:current_user) { create(:admin) }
  let_it_be(:organization) { create(:organization) }

  let(:params) do
    {
      name: 'John Doe',
      username: 'jduser',
      email: 'jd@example.com',
      password: User.random_password,
      organization_id: organization.id
    }
  end

  subject(:service) { described_class.new(current_user, params) }

  describe '#execute' do
    context "when licensed" do
      before do
        stub_licensed_features(extended_audit_events: true)
      end

      context 'audit events' do
        it 'logs the audit event info' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(
            name: 'user_created'
          )).and_call_original

          # user creation will also send confirmation instructions which is also audited
          allow(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(name: 'email_confirmation_sent'))

          user = service.execute.payload[:user]

          expect(AuditEvent.last).to have_attributes(
            author_id: current_user.id,
            entity_id: user.id,
            entity_type: 'User',
            details: {
              add: 'user',
              author_class: 'User',
              author_name: current_user.name,
              custom_message: "User #{user.username} created",
              event_name: "user_created",
              target_id: user.id,
              target_type: 'User',
              target_details: user.full_path,
              registration_details: {
                id: user.id,
                name: user.name,
                username: user.username,
                email: user.email,
                access_level: user.access_level
              }
            }
          )
        end

        it 'does not log audit event if operation fails' do
          expect_any_instance_of(User).to receive(:save).and_return(false)

          expect { service.execute }.not_to change { AuditEvent.count }
        end
      end

      context 'when audit is not required' do
        let(:current_user) { nil }

        it 'does not log any audit event' do
          allow(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(name: 'email_created'))

          expect { service.execute }.not_to change(AuditEvent, :count)
        end
      end
    end
  end

  describe 'with a subscription' do
    let(:seats) { 0 }

    before do
      create_current_license(plan: License::PREMIUM_PLAN, seats: seats)

      stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_BLOCK_OVERAGES)
    end

    describe 'with licensed users' do
      let(:seats) { 10 }

      describe 'when licensed user count reached' do
        let_it_be(:group) { create(:group) }
        let(:seats) { 1 }

        before_all do
          group.add_guest(current_user)
        end

        context 'when new user will have a membership' do
          let(:params) do
            {
              name: 'John Doe',
              username: 'jduser',
              email: 'jd@example.com',
              password: User.random_password,
              organization_id: organization.id,
              projects_limit: 10
            }
          end

          before do
            allow_next_instance_of(User) do |user|
              allow(user).to receive(:using_license_seat?).and_return(true)
            end
          end

          it 'does not create a user' do
            expect { service.execute }.not_to change(User, :count)
          end

          it 'returns an error' do
            expect(service.execute).to have_attributes(
              message: 'NO_SEATS_AVAILABLE',
              status: :error
            )
          end
        end

        context 'when new user will not have a membership' do
          it 'creates a user because they will not consume a seat' do
            expect { service.execute }.to change(User, :count).by(1)
          end

          it 'returns success' do
            expect(service.execute).to have_attributes(
              status: :success
            )
          end
        end

        context 'when seat control feature is not licensed' do
          before do
            stub_licensed_features(seat_control: false)
          end

          it 'creates a user' do
            expect { service.execute }.to change(User, :count).by(1)
          end
        end

        context 'when block overages is disabled' do
          before do
            stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_OFF)
          end

          it 'creates a user' do
            expect { service.execute }.to change(User, :count).by(1)
          end
        end
      end

      it 'creates a user' do
        expect { service.execute }.to change(User, :count).by(1)
      end
    end

    it 'creates a user' do
      expect { service.execute }.to change(User, :count).by(1)
    end
  end

  context 'when not licensed' do
    before do
      stub_licensed_features(
        admin_audit_log: false,
        audit_events: false,
        extended_audit_events: false
      )
    end

    it 'does not log audit event' do
      expect { service.execute }.not_to change(AuditEvent, :count)
    end
  end
end
