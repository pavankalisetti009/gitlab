# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PushRules::CreateOrUpdateService, feature_category: :source_code_management do
  let_it_be_with_reload(:container) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:params) { { max_file_size: 28 } }

  subject(:service) { described_class.new(container: container, current_user: user, params: params) }

  shared_examples 'a failed update' do
    let(:params) { { max_file_size: -28 } }

    context 'and read_and_write_group_push_rules is disabled' do
      before do
        stub_feature_flags(read_and_write_group_push_rules: false)
      end

      it 'responds with an error service response', :aggregate_failures do
        response = service.execute

        expect(response).to be_error
        expect(response.message).to eq('Max file size must be greater than or equal to 0')
        expect(response.payload).to match(push_rule: container.push_rule)
      end
    end
  end

  context 'when container is an organization' do
    let_it_be(:container) { create(:organization) }

    context 'with existing global push rule' do
      let_it_be(:push_rule) { create(:organization_push_rule, organization_id: container.id) }

      context "when update_organization_push_rules FF is disabled" do
        before do
          stub_feature_flags(update_organization_push_rules: false)
        end

        let_it_be(:push_rule) { create(:push_rule_sample) }

        it 'updates existing global push rule' do
          expect { subject.execute }
            .to not_change { PushRule.count }
            .and change { push_rule.reload.max_file_size }.to(28)
        end
      end

      it 'updates existing organization push rule' do
        expect { subject.execute }
          .to not_change { OrganizationPushRule.count }
          .and change { push_rule.reload.max_file_size }.to(28)
      end

      it 'returns OrganizationPushRule in a successful service response', :aggregate_failures do
        response = subject.execute

        expect(response).to be_success
        expect(response.payload).to match(push_rule: PushRuleFinder.new(container).execute)
      end

      context 'with read_organization_push_rules feature flag disabled' do
        before do
          stub_feature_flags(read_organization_push_rules: false)
        end

        it 'returns PushRule in a successful service response', :aggregate_failures do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to match(push_rule: push_rule)
        end
      end
    end

    context 'without existing global push rule' do
      context 'with read_organization_push_rules feature flag disabled' do
        before do
          stub_feature_flags(read_organization_push_rules: false)
        end

        context "when update_organization_push_rules FF is disabled" do
          before do
            stub_feature_flags(update_organization_push_rules: false)
          end

          it 'creates a new push rule', :aggregate_failures do
            expect { subject.execute }.to change { PushRule.count }.by(1)

            expect(PushRuleFinder.new(container).execute.max_file_size).to eq(28)
          end
        end

        it 'creates a new organization push rule', :aggregate_failures do
          expect { subject.execute }.to change { OrganizationPushRule.count }.by(1)

          expect(PushRuleFinder.new(container).execute.max_file_size).to eq(28)
        end

        it 'does not create a new push rule', :aggregate_failures do
          expect { subject.execute }.not_to change { PushRule.count }
        end

        it 'responds with a successful service response', :aggregate_failures do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to match(push_rule: PushRuleFinder.new(container).execute)
        end
      end

      it 'creates a new push rule', :aggregate_failures do
        expect { service.execute }.to change { OrganizationPushRule.count }.by(1)

        expect(PushRuleFinder.new(container).execute.max_file_size).to eq(28)
      end

      it 'responds with a successful service response', :aggregate_failures do
        response = service.execute

        expect(response).to be_success
        expect(response.payload).to match(push_rule: PushRuleFinder.new(container).execute)
      end
    end

    context 'with filtering for organization containers' do
      let_it_be(:push_rule) { create(:push_rule_sample, organization: container) }

      before do
        allow(service).to receive(:push_rule).and_return(push_rule)
      end

      context 'with allowed and unsupported fields' do
        let(:params) { { unsupported_field: 1, max_file_size: 20 } }

        it 'filters out unsupported fields and keeps allowed fields' do
          expect(push_rule).to receive(:update).with({ max_file_size: 20 })

          service.execute
        end
      end

      context 'with conditional field when available' do
        let(:params) { { max_file_size: 20, reject_unsigned_commits: true } }

        it 'includes conditional field when license allows it' do
          allow(push_rule).to receive(:available?).and_return(false)
          allow(push_rule).to receive(:available?).with(:reject_unsigned_commits).and_return(true)

          expect(push_rule).to receive(:update).with({ max_file_size: 20, reject_unsigned_commits: true })

          service.execute
        end
      end

      context 'with conditional field when not available' do
        let(:params) { { max_file_size: 20, reject_unsigned_commits: true } }

        before do
          stub_licensed_features(reject_unsigned_commits: false)
        end

        it 'excludes conditional field when license does not allow it' do
          expect(push_rule).to receive(:update).with({ max_file_size: 20 })

          service.execute
        end
      end
    end
  end

  context 'when container is a group' do
    let(:container) { create(:group) }

    context 'with existing group push rule' do
      let(:group_push_rule) { create(:group_push_rule, group: container) }

      it 'updates existing group push rule' do
        expect { service.execute }
          .to not_change { GroupPushRule.count }
                .and change { group_push_rule.reload.max_file_size }.to(28)
      end

      it 'responds with a successful service response', :aggregate_failures do
        response = service.execute

        expect(response).to be_success
        expect(response.payload).to match(push_rule: container.group_push_rule)
      end

      context 'with a failed update' do
        let(:params) { { max_file_size: -28 } }

        it 'responds with an error service response', :aggregate_failures do
          response = service.execute

          expect(response).to be_error
          expect(response.message).to eq('Max file size must be greater than or equal to 0')
          expect(response.payload).to match(push_rule: container.group_push_rule)
        end
      end
    end

    context 'without existing group push rule' do
      let(:group_push_rule) { nil }

      it 'creates a new group push rule', :aggregate_failures do
        expect { service.execute }.to change { GroupPushRule.count }.by(1)

        expect(container.group_push_rule.max_file_size).to eq(28)
      end

      it 'responds with a successful service response', :aggregate_failures do
        response = service.execute

        expect(response).to be_success
        expect(response.payload).to match(push_rule: container.group_push_rule)
      end
    end

    context 'with read_and_write_group_push_rules disabled' do
      let(:container) { create(:group, push_rule: push_rule) }

      before do
        stub_feature_flags(read_and_write_group_push_rules: false)
      end

      context 'with existing push rule' do
        let_it_be(:push_rule) { create(:push_rule, project: nil, organization: nil) }

        it 'updates existing push rule' do
          expect { service.execute }
            .to not_change { PushRule.count }
                  .and change { push_rule.reload.max_file_size }.to(28)
                  .and change { push_rule.reload.organization_id }.to(container.organization_id)
        end

        it 'responds with a successful service response', :aggregate_failures do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to match(push_rule: push_rule)
        end

        it_behaves_like 'a failed update'
      end

      context 'without existing push rule' do
        let(:push_rule) { nil }

        it 'creates a new push rule', :aggregate_failures do
          expect { service.execute }.to change { PushRule.count }.by(1)

          expect(container.push_rule.max_file_size).to eq(28)
          expect(container.push_rule.organization_id).to eq(container.organization_id)
        end

        it 'responds with a successful service response', :aggregate_failures do
          response = service.execute

          expect(response).to be_success
          expect(response.payload).to match(push_rule: container.push_rule)
        end

        it_behaves_like 'a failed update'
      end
    end
  end

  context 'with existing push rule' do
    let_it_be(:push_rule) { create(:push_rule, project: container) }

    it 'updates existing push rule' do
      expect { service.execute }
        .to not_change { PushRule.count }
        .and change { push_rule.reload.max_file_size }.to(28)
    end

    it 'responds with a successful service response', :aggregate_failures do
      response = service.execute

      expect(response).to be_success
      expect(response.payload).to match(push_rule: push_rule)
    end

    context 'when container is a group' do
      let_it_be(:container) { create(:group) }

      it 'audits the changes' do
        expect { service.execute }.to change { AuditEvent.count }.by(1)
      end
    end

    it_behaves_like 'a failed update'
  end

  context 'without existing push rule' do
    it 'creates a new push rule', :aggregate_failures do
      expect { service.execute }.to change { PushRule.count }.by(1)

      expect(container.push_rule.max_file_size).to eq(28)
    end

    it 'responds with a successful service response', :aggregate_failures do
      response = service.execute

      expect(response).to be_success
      expect(response.payload).to match(push_rule: container.push_rule)
    end

    it_behaves_like 'a failed update'
  end
end
