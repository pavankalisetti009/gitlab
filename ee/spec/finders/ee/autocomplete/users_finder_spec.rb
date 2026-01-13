# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Autocomplete::UsersFinder, feature_category: :code_review_workflow do
  describe '#execute' do
    let(:current_user) { create(:user) }
    let(:params) { {} }

    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject(:users) do
      described_class.new(params: params, current_user: current_user, project: project, group: nil).execute.to_a
    end

    describe '#project_users' do
      context 'when project does not have access to Duo Code review' do
        before do
          allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(false)
        end

        it { is_expected.not_to include(::Users::Internal.duo_code_review_bot) }
      end

      context 'when project has access Duo Code review' do
        before do
          allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(true)
        end

        it { is_expected.to include(::Users::Internal.duo_code_review_bot) }
      end
    end

    describe 'hide_service_accounts_without_flow_triggers' do
      let_it_be(:flow_without_triggers) { create(:ai_catalog_item, :flow, project: project) }
      let_it_be(:flow_with_triggers) { create(:ai_catalog_item, :flow, project: project) }

      let_it_be(:service_account_without_triggers) do
        create(:service_account, composite_identity_enforced: true, provisioned_by_group: group)
      end

      let_it_be(:service_account_with_triggers) do
        create(:service_account, composite_identity_enforced: true, provisioned_by_group: group)
      end

      let_it_be(:group_item_consumer_without_triggers) do
        create(
          :ai_catalog_item_consumer,
          group: group,
          item: flow_without_triggers,
          service_account: service_account_without_triggers
        )
      end

      let_it_be(:project_item_consumer_without_triggers) do
        create(
          :ai_catalog_item_consumer,
          project: project,
          item: flow_without_triggers,
          service_account: nil,
          parent_item_consumer: group_item_consumer_without_triggers
        )
      end

      let_it_be(:group_item_consumer_with_triggers) do
        create(
          :ai_catalog_item_consumer,
          group: group,
          item: flow_with_triggers,
          service_account: service_account_with_triggers
        )
      end

      let_it_be(:project_item_consumer_with_triggers) do
        create(
          :ai_catalog_item_consumer,
          project: project,
          item: flow_with_triggers,
          service_account: nil,
          parent_item_consumer: group_item_consumer_with_triggers
        )
      end

      before_all do
        project.add_developer(service_account_with_triggers)
        project.add_developer(service_account_without_triggers)

        # Flow trigger for `flow_with_trigger`
        create(
          :ai_flow_trigger,
          ai_catalog_item_consumer: project_item_consumer_with_triggers,
          project: project,
          config_path: nil,
          user: service_account_with_triggers
        )
      end

      context 'when nil' do
        it 'includes service accounts with no triggers' do
          expect(users).to include(service_account_with_triggers, service_account_without_triggers)
        end
      end

      context 'when false' do
        let(:params) { { hide_service_accounts_without_flow_triggers: false } }

        it 'includes service accounts with no triggers' do
          expect(users).to include(service_account_with_triggers, service_account_without_triggers)
        end
      end

      context 'when true' do
        let(:params) { { hide_service_accounts_without_flow_triggers: true } }

        it 'excludes service accounts with no triggers' do
          expect(users)
            .to include(service_account_with_triggers)
            .and not_include(service_account_without_triggers)
        end
      end
    end
  end
end
