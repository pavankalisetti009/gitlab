# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::IpRestriction::Enforcer, feature_category: :system_access do
  describe '#allows_current_ip?' do
    let(:group) { create(:group) }
    let(:current_ip) { '192.168.0.2' }

    shared_examples 'ip_restriction' do
      context 'without restriction' do
        it { is_expected.to be_truthy }
      end

      context 'with restriction' do
        before do
          stub_application_setting(globally_allowed_ips: "")

          ranges.each do |range|
            create(:ip_restriction, group: group, range: range)
          end
        end

        context 'address is within one of the ranges' do
          let(:ranges) { ['192.168.0.0/24', '255.255.255.224/27'] }

          it { is_expected.to be_truthy }
        end

        context 'address is outside all of the ranges' do
          let(:ranges) { ['10.0.0.0/8', '255.255.255.224/27'] }

          it { is_expected.to be_falsey }

          context 'address is in globally allowed ip range' do
            before do
              stub_application_setting(globally_allowed_ips: "192.168.0.0/24")
            end

            it { is_expected.to be_truthy }

            context 'address is outside globally allowed ip range' do
              before do
                stub_application_setting(globally_allowed_ips: "255.168.0.0/24")
              end

              it { is_expected.to be_falsey }
            end
          end
        end
      end
    end

    subject { described_class.new(group).allows_current_ip? }

    before do
      allow(Gitlab::IpAddressState).to receive(:current).and_return(current_ip)
      stub_licensed_features(group_ip_restriction: true)
    end

    it_behaves_like 'ip_restriction'

    context 'group_ip_restriction feature is disabled' do
      before do
        stub_licensed_features(group_ip_restriction: false)
      end

      it { is_expected.to be_truthy }
    end

    context 'when usage ping is enabled' do
      before do
        allow(License).to receive(:current).and_return(nil)
        stub_application_setting(usage_ping_enabled: true)
      end

      context 'when usage_ping_features_enabled is enabled' do
        before do
          stub_application_setting(usage_ping_features_enabled: true)
        end

        it_behaves_like 'ip_restriction'
      end

      context 'when usage_ping_features_enabled is disabled' do
        before do
          stub_application_setting(usage_ping_features_enabled: false)
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when usage ping is disabled' do
      before do
        stub_licensed_features(group_ip_restriction: false)
        stub_application_setting(usage_ping_enabled: false)
      end

      it { is_expected.to be_truthy }
    end
  end

  describe 'audit events and logging' do
    let(:group) { create(:group) }
    let(:current_ip) { '192.168.0.2' }
    let(:user) { create(:user) }
    let(:enforcer) { described_class.new(group) }
    let(:logger) { instance_double(Gitlab::AuthLogger) }

    before do
      allow(Gitlab::IpAddressState).to receive(:current).and_return(current_ip)
      allow(Gitlab::AuthLogger).to receive(:build).and_return(logger)
      stub_licensed_features(group_ip_restriction: true)
      allow(Gitlab::ApplicationContext).to receive(:current_context_attribute).and_call_original
      allow(Gitlab::ApplicationContext).to receive(:current_context_attribute).with(:user).and_return(user.username)
      allow(User).to receive(:find_by_username).with(user.username).and_return(user)
    end

    context 'when IP restrictions are present' do
      before do
        stub_application_setting(globally_allowed_ips: "")
        create(:ip_restriction, group: group, range: '192.168.0.0/24')
      end

      it 'calls Gitlab::Audit::Auditor and logs when access is allowed' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with({
          name: 'ip_restricted_group_accessed',
          author: user,
          scope: group,
          target: group,
          message: 'Attempting to access IP restricted group',
          additional_details: {
            allowed: true,
            ip_address: current_ip,
            group_full_path: group.full_path,
            global_allowlist_in_use: false
          }
        })

        expect(logger).to receive(:info).with(
          message: 'Attempting to access IP restricted group',
          allowed: true,
          ip_address: current_ip,
          group_full_path: group.full_path,
          global_allowlist_in_use: false
        )

        enforcer.allows_current_ip?
      end

      it 'calls Gitlab::Audit::Auditor and logs when access is denied' do
        allow(Gitlab::IpAddressState).to receive(:current).and_return('10.0.0.1')

        expect(Gitlab::Audit::Auditor).to receive(:audit).with({
          name: 'ip_restricted_group_accessed',
          author: user,
          scope: group,
          target: group,
          message: 'Attempting to access IP restricted group',
          additional_details: {
            allowed: false,
            ip_address: '10.0.0.1',
            group_full_path: group.full_path,
            global_allowlist_in_use: false
          }
        })

        expect(logger).to receive(:info).with(
          message: 'Attempting to access IP restricted group',
          allowed: false,
          ip_address: '10.0.0.1',
          group_full_path: group.full_path,
          global_allowlist_in_use: false
        )

        enforcer.allows_current_ip?
      end

      it 'includes global_allowlist_in_use when globally_allowed_ips is configured' do
        stub_application_setting(globally_allowed_ips: "172.16.0.0/12")

        expect(Gitlab::Audit::Auditor).to receive(:audit).with({
          name: 'ip_restricted_group_accessed',
          author: user,
          scope: group,
          target: group,
          message: 'Attempting to access IP restricted group',
          additional_details: {
            allowed: true,
            ip_address: current_ip,
            group_full_path: group.full_path,
            global_allowlist_in_use: true
          }
        })

        expect(logger).to receive(:info).with(
          message: 'Attempting to access IP restricted group',
          allowed: true,
          ip_address: current_ip,
          group_full_path: group.full_path,
          global_allowlist_in_use: true
        )

        enforcer.allows_current_ip?
      end

      context 'when user is not authenticated' do
        before do
          allow(Gitlab::ApplicationContext).to receive(:current_context_attribute).and_call_original
          allow(Gitlab::ApplicationContext).to receive(:current_context_attribute).with(:user).and_return(nil)
        end

        it 'uses UnauthenticatedAuthor when user is nil' do
          expect(Gitlab::Audit::Auditor).to receive(:audit).with({
            name: 'ip_restricted_group_accessed',
            author: instance_of(Gitlab::Audit::UnauthenticatedAuthor),
            scope: group,
            target: group,
            message: 'Attempting to access IP restricted group',
            additional_details: {
              allowed: true,
              ip_address: current_ip,
              group_full_path: group.full_path,
              global_allowlist_in_use: false
            }
          })

          expect(logger).to receive(:info).with(
            message: 'Attempting to access IP restricted group',
            allowed: true,
            ip_address: current_ip,
            group_full_path: group.full_path,
            global_allowlist_in_use: false
          )

          enforcer.allows_current_ip?
        end
      end
    end

    context 'when IP restrictions are not present' do
      it 'does not call Gitlab::Audit::Auditor or log when there are no restrictions' do
        expect(Gitlab::Audit::Auditor).not_to receive(:audit)
        expect(logger).not_to receive(:info)

        enforcer.allows_current_ip?
      end
    end

    context 'when group_ip_restriction feature is disabled' do
      before do
        stub_licensed_features(group_ip_restriction: false)
        create(:ip_restriction, group: group, range: '192.168.0.0/24')
      end

      it 'does not call Gitlab::Audit::Auditor or log' do
        expect(Gitlab::Audit::Auditor).not_to receive(:audit)
        expect(logger).not_to receive(:info)

        enforcer.allows_current_ip?
      end
    end
  end
end
