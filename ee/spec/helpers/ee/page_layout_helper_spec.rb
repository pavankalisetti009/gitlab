# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::PageLayoutHelper, feature_category: :shared do
  describe '#duo_chat_panel_data' do
    let_it_be(:user) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for global_id
    let(:project) { build(:project) }
    let(:group) { build(:group) }

    before do
      allow(::Gitlab::Llm::TanukiBot).to receive_messages(user_model_selection_enabled?: false,
        agentic_mode_available?: false, root_namespace_id: 'root-123', resource_id: 'resource-456',
        chat_disabled_reason: nil, credits_available?: true, default_duo_namespace: nil)
      allow(::Gitlab::DuoWorkflow::Client).to receive(:metadata).and_return({ key: 'value' })
      allow(::Ai::AmazonQ).to receive_messages(enabled?: false, connected?: false)
      allow(Gitlab::Saas).to receive(:feature_available?).and_call_original
      allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
    end

    it 'returns user global id' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:user_id]).to eq(user.to_global_id)
    end

    context 'when project is persisted' do
      let(:project) { create(:project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for persist check

      it 'returns project global id when project is persisted' do
        result = helper.duo_chat_panel_data(user, project, group)

        expect(result[:project_id]).to eq(project.to_global_id)
      end
    end

    it 'returns nil project id when project is not persisted' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:project_id]).to be_nil
    end

    it 'returns nil project id when project is nil' do
      result = helper.duo_chat_panel_data(user, nil, group)

      expect(result[:project_id]).to be_nil
    end

    context 'when group is persisted' do
      let(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for persist check

      it 'returns group global id when group is persisted' do
        result = helper.duo_chat_panel_data(user, project, group)

        expect(result[:namespace_id]).to eq(group.to_global_id)
      end
    end

    it 'returns nil namespace id when group is not persisted' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:namespace_id]).to be_nil
    end

    it 'returns nil namespace id when group is nil' do
      result = helper.duo_chat_panel_data(user, project, nil)

      expect(result[:namespace_id]).to be_nil
    end

    it 'returns root namespace id from TanukiBot' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:root_namespace_id]).to eq('root-123')
    end

    it 'returns resource id from TanukiBot' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:resource_id]).to eq('resource-456')
    end

    it 'returns metadata as JSON string' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:metadata]).to eq('{"key":"value"}')
    end

    it 'returns user model selection enabled as string' do
      allow(Gitlab::Llm::TanukiBot).to receive(:user_model_selection_enabled?).and_return(true)

      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:user_model_selection_enabled]).to eq('true')
    end

    it 'returns agentic available as string' do
      allow(Gitlab::Llm::TanukiBot).to receive(:agentic_mode_available?).and_return(true)

      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:agentic_available]).to eq('true')
    end

    it 'returns credits available as string when true' do
      allow(Gitlab::Llm::TanukiBot).to receive(:credits_available?).and_return(true)

      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:credits_available]).to eq('true')
    end

    it 'returns credits available as string when false' do
      allow(Gitlab::Llm::TanukiBot).to receive(:credits_available?).and_return(false)

      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:credits_available]).to eq('false')
    end

    it 'returns default chat title when AmazonQ is disabled' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:chat_title]).to eq(s_('GitLab Duo Chat'))
    end

    it 'returns AmazonQ chat title when AmazonQ is enabled' do
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(true)

      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:chat_title]).to eq(s_('GitLab Duo Chat with Amazon Q'))
    end

    it 'calls TanukiBot methods with project taking priority' do
      expect(Gitlab::Llm::TanukiBot).to receive(:user_model_selection_enabled?).with(user: user, scope: project)
      expect(Gitlab::Llm::TanukiBot).to receive(:agentic_mode_available?).with(
        user: user, project: project, group: group
      )
      expect(Gitlab::Llm::TanukiBot).to receive(:credits_available?).with(
        user: user, project: project, group: group
      )

      helper.duo_chat_panel_data(user, project, group)
    end

    it 'calls TanukiBot methods with group when project is absent' do
      expect(Gitlab::Llm::TanukiBot).to receive(:user_model_selection_enabled?).with(user: user, scope: group)
      expect(Gitlab::Llm::TanukiBot).to receive(:agentic_mode_available?).with(
        user: user, project: nil, group: group
      )
      expect(Gitlab::Llm::TanukiBot).to receive(:credits_available?).with(
        user: user, project: nil, group: group
      )

      helper.duo_chat_panel_data(user, nil, group)
    end

    it 'calls DuoWorkflow Client metadata with user' do
      expect(Gitlab::DuoWorkflow::Client).to receive(:metadata).with(user)

      helper.duo_chat_panel_data(user, project, group)
    end

    it 'returns chat_disabled_reason as empty string when chat is enabled' do
      result = helper.duo_chat_panel_data(user, project, group)

      expect(result[:chat_disabled_reason]).to eq('')
    end

    context 'when chat is disabled for project' do
      before do
        allow(::Gitlab::Llm::TanukiBot).to receive(:chat_disabled_reason)
          .with(user: user, container: project)
          .and_return(:project)
      end

      it 'returns chat_disabled_reason as "project"' do
        result = helper.duo_chat_panel_data(user, project, nil)

        expect(result[:chat_disabled_reason]).to eq('project')
      end
    end

    context 'when chat is disabled for group' do
      before do
        allow(::Gitlab::Llm::TanukiBot).to receive(:chat_disabled_reason)
          .with(user: user, container: group)
          .and_return(:group)
      end

      it 'returns chat_disabled_reason as "group"' do
        result = helper.duo_chat_panel_data(user, nil, group)

        expect(result[:chat_disabled_reason]).to eq('group')
      end
    end

    context 'when group context is absent' do
      let(:default_namespace) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- for persist check

      before do
        allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(default_namespace)
      end

      it 'does not use default namespace for namespace_id when project is present' do
        result = helper.duo_chat_panel_data(user, project, nil)

        expect(result[:namespace_id]).to be_nil
      end
    end

    context 'when no namespace context is available' do
      subject(:result) { helper.duo_chat_panel_data(user, nil, nil) }

      context 'when default_duo_namespace returns nil' do
        before do
          allow(Gitlab::Llm::TanukiBot).to receive(:default_duo_namespace).and_return(nil)
        end

        it 'handles nil default namespace gracefully' do
          expect(result[:is_trial]).to eq('false')
          expect(result[:can_buy_addon]).to eq('false')
          expect(result[:buy_addon_path]).to be_nil
        end
      end

      context 'when default_duo_namespace returns a namespace' do
        let_it_be(:default_group) { build_stubbed(:group) }

        before do
          allow(Gitlab::Llm::TanukiBot).to receive(:default_duo_namespace).and_return(default_group)
          allow(default_group).to receive(:trial_active?).and_return(false)
          allow(helper).to receive(:can?).with(user, :edit_billing, default_group).and_return(false)
        end

        it 'uses default namespace for billing attributes' do
          expect(result[:is_trial]).to eq('false')
        end
      end
    end

    describe 'trial and billing attributes' do
      subject(:result) { helper.duo_chat_panel_data(user, nil, root_group) }

      let_it_be(:root_group) { build_stubbed(:group) }

      before do
        allow(Gitlab::Llm::TanukiBot).to receive(:default_duo_namespace).and_return(root_group)
      end

      context 'when namespace has active trial' do
        before do
          allow(root_group).to receive(:trial_active?).and_return(true)
        end

        it 'returns is_trial as "true"' do
          expect(result[:is_trial]).to eq('true')
        end
      end

      context 'when namespace does not have active trial' do
        before do
          allow(root_group).to receive(:trial_active?).and_return(false)
        end

        it 'returns is_trial as "false"' do
          expect(result[:is_trial]).to eq('false')
        end
      end

      context 'when user can edit billing' do
        before do
          allow(helper).to receive(:can?).with(user, :edit_billing, root_group).and_return(true)
        end

        context 'when not on trial' do
          before do
            allow(root_group).to receive(:trial_active?).and_return(false)
          end

          it 'returns can_buy_addon as "true"' do
            expect(result[:can_buy_addon]).to eq('true')
          end

          it 'returns credits dashboard path for buy_addon_path' do
            expect(result[:buy_addon_path]).to eq(helper.group_settings_gitlab_credits_dashboard_index_path(root_group))
          end
        end

        context 'when on trial' do
          before do
            allow(root_group).to receive(:trial_active?).and_return(true)
          end

          it 'returns can_buy_addon as "true"' do
            expect(result[:can_buy_addon]).to eq('true')
          end

          it 'returns subscription portal URL for buy_addon_path' do
            expect(result[:buy_addon_path]).to eq(::Gitlab::Routing.url_helpers.subscription_portal_url)
          end
        end
      end

      context 'when user cannot edit billing' do
        before do
          allow(helper).to receive(:can?).with(user, :edit_billing, root_group).and_return(false)
          allow(root_group).to receive(:trial_active?).and_return(false)
        end

        it 'returns can_buy_addon as "false"' do
          expect(result[:can_buy_addon]).to eq('false')
        end

        it 'returns nil buy_addon_path' do
          expect(result[:buy_addon_path]).to be_nil
        end
      end

      context 'when namespace is nil' do
        subject(:result) { helper.duo_chat_panel_data(user, nil, nil) }

        before do
          allow(Gitlab::Llm::TanukiBot).to receive(:default_duo_namespace).and_return(nil)
        end

        it 'returns is_trial as "false"' do
          expect(result[:is_trial]).to eq('false')
        end

        it 'returns can_buy_addon as "false"' do
          expect(result[:can_buy_addon]).to eq('false')
        end

        it 'returns nil buy_addon_path' do
          expect(result[:buy_addon_path]).to be_nil
        end
      end

      context 'on self-managed instance' do
        before do
          allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(false)
        end

        context 'when user is admin' do
          before do
            allow(helper).to receive(:can?).with(user, :admin_all_resources).and_return(true)
          end

          context 'when no license' do
            before do
              allow(License).to receive(:current).and_return(nil)
            end

            it 'returns is_trial as empty string' do
              expect(result[:is_trial]).to eq('')
            end
          end

          context 'when not on trial' do
            before do
              allow(License).to receive(:current).and_return(instance_double(License, trial?: false, paid?: true))
            end

            it 'returns can_buy_addon as "true"' do
              expect(result[:can_buy_addon]).to eq('true')
            end

            it 'returns admin credits dashboard path for buy_addon_path' do
              expect(result[:buy_addon_path]).to eq(helper.admin_gitlab_credits_dashboard_index_path)
            end
          end

          context 'when on trial' do
            before do
              allow(License).to receive(:current).and_return(instance_double(License, trial?: true, paid?: false))
            end

            it 'returns can_buy_addon as "true"' do
              expect(result[:can_buy_addon]).to eq('true')
            end

            it 'returns subscription portal URL for buy_addon_path' do
              expect(result[:buy_addon_path]).to eq(::Gitlab::Routing.url_helpers.subscription_portal_url)
            end
          end
        end

        context 'when user is not admin' do
          before do
            allow(helper).to receive(:can?).with(user, :admin_all_resources).and_return(false)
          end

          it 'returns can_buy_addon as "false"' do
            expect(result[:can_buy_addon]).to eq('false')
          end

          it 'returns nil buy_addon_path' do
            expect(result[:buy_addon_path]).to be_nil
          end
        end
      end

      context 'on SaaS instance' do
        context 'when user can edit billing' do
          before do
            allow(helper).to receive(:can?).with(user, :edit_billing, root_group).and_return(true)
          end

          context 'when not on trial' do
            before do
              allow(root_group).to receive(:trial_active?).and_return(false)
            end

            it 'returns group settings path for buy_addon_path' do
              expect(result[:buy_addon_path]).to eq(
                helper.group_settings_gitlab_credits_dashboard_index_path(root_group)
              )
            end
          end

          context 'when on trial' do
            before do
              allow(root_group).to receive(:trial_active?).and_return(true)
            end

            it 'returns subscription portal URL for buy_addon_path' do
              expect(result[:buy_addon_path]).to eq(::Gitlab::Routing.url_helpers.subscription_portal_url)
            end
          end
        end
      end
    end

    describe 'trial and subscription attributes' do
      context 'when SaaS subscriptions feature is available' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        it 'returns nil trial and subscription status when project and group are nil' do
          result = helper.duo_chat_panel_data(user, nil, nil)

          expect(result[:trial_active]).to be_nil
          expect(result[:subscription_active]).to be_nil
        end

        context 'with group namespace' do
          let(:group) { build(:group) }
          let(:root_namespace) { build(:group) }

          before do
            allow(group).to receive(:root_ancestor).and_return(root_namespace)
            allow(root_namespace).to receive(:trial_active?).and_return(true)
            allow(GitlabSubscriptions).to receive(:active?).with(root_namespace).and_return(false)
          end

          it 'returns root namespace trial and subscription status' do
            result = helper.duo_chat_panel_data(user, nil, group)

            expect(result[:trial_active]).to eq('true')
            expect(result[:subscription_active]).to eq('false')
          end
        end

        context 'with project namespace' do
          let(:project) { build(:project) }
          let(:root_namespace) { build(:group) }

          before do
            allow(project).to receive(:root_ancestor).and_return(root_namespace)
            allow(root_namespace).to receive(:trial_active?).and_return(false)
            allow(GitlabSubscriptions).to receive(:active?).with(root_namespace).and_return(true)
          end

          it 'returns project root namespace trial and subscription status' do
            result = helper.duo_chat_panel_data(user, project, nil)

            expect(result[:trial_active]).to eq('false')
            expect(result[:subscription_active]).to eq('true')
          end
        end

        context 'when namespace is absent' do
          let(:project) { build(:project) }

          before do
            allow(project).to receive(:root_ancestor).and_return(nil)
          end

          it 'returns nil for trial and subscription status' do
            result = helper.duo_chat_panel_data(user, project, nil)

            expect(result[:trial_active]).to be_nil
            expect(result[:subscription_active]).to be_nil
          end
        end
      end

      context 'when SaaS subscriptions feature is not available' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        context 'when License.current is present' do
          before do
            license = build(:license, trial: true)
            allow(License).to receive(:current).and_return(license)
          end

          it 'returns license trial and subscription status' do
            result = helper.duo_chat_panel_data(user, nil, nil)

            expect(result[:trial_active]).to eq('true')
            expect(result[:subscription_active]).to eq('true')
          end
        end

        context 'when License.current is nil' do
          before do
            allow(License).to receive(:current).and_return(nil)
          end

          it 'returns nil for trial and subscription status' do
            result = helper.duo_chat_panel_data(user, nil, nil)

            expect(result[:trial_active]).to be_nil
            expect(result[:subscription_active]).to be_nil
          end
        end

        context 'when License.current is paid' do
          before do
            license = build(:license, trial: false)
            allow(License).to receive(:current).and_return(license)
          end

          it 'returns paid subscription status' do
            result = helper.duo_chat_panel_data(user, nil, nil)

            expect(result[:trial_active]).to eq('')
            expect(result[:subscription_active]).to eq('true')
          end
        end
      end
    end
  end

  describe '#should_auto_expand_duo_panel?' do
    context 'when user is not signed in' do
      let(:user) { nil }

      it 'returns false' do
        expect(helper.should_auto_expand_duo_panel?(user)).to be(false)
      end
    end

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- needed for callout association
    # Using `let` instead of `let_it_be` to avoid memoization issues with user.callouts_by_feature_name
    context 'when user has not dismissed the callout' do
      let(:user) { create(:user) }

      it 'returns true' do
        expect(helper.should_auto_expand_duo_panel?(user)).to be(true)
      end
    end

    context 'when user has dismissed the callout' do
      let(:user) { create(:user) }

      before do
        create(:callout, user: user, feature_name: 'duo_panel_auto_expanded')
      end

      it 'returns false' do
        expect(helper.should_auto_expand_duo_panel?(user)).to be(false)
      end
    end
    # rubocop:enable RSpec/FactoryBot/AvoidCreate
  end

  describe '#duo_chat_panel_empty_state_data' do
    let(:user_namespace) { build_stubbed(:namespace) }
    let(:user) { build_stubbed(:user, namespace: user_namespace) }
    let(:group) { build(:group) }
    let(:project_owned_by_user) { build(:project, namespace: user_namespace) }
    let(:project_owned_by_group) { build(:project, namespace: group) }
    let(:source) { nil }

    subject(:duo_chat_panel_empty_state_data) { helper.duo_chat_panel_empty_state_data(source: source) }

    before do
      allow(helper).to receive(:current_user) { user }
      allow(Ability).to receive(:allowed?).and_call_original
    end

    context 'on .com', :saas_gitlab_com_subscriptions do
      before do
        allow(group).to receive(:has_free_or_no_subscription?).and_return(has_free_or_no_subscription?)
        allow(Ability).to receive(:allowed?).with(user, :admin_namespace, group).and_return(can_admin_namespace?)
      end

      context 'when user cannot start a trial due to lack of permissions in the namespace' do
        let(:can_admin_namespace?) { false }
        let(:has_free_or_no_subscription?) { true }
        let(:source) { group }

        it 'returns the correct data' do
          is_expected.to eq({
            namespace_type: 'Group'
          })
        end
      end

      context 'when user cannot start a trial due to the namespace already having some sort of subscription' do
        let(:can_admin_namespace?) { true }
        let(:has_free_or_no_subscription?) { false }
        let(:source) { group }

        it 'returns the correct data' do
          is_expected.to eq({
            namespace_type: 'Group'
          })
        end
      end

      context 'when user can start a trial' do
        let(:can_admin_namespace?) { true }
        let(:has_free_or_no_subscription?) { true }

        context 'when there is no namespace' do
          it 'returns the correct data' do
            is_expected.to eq({
              new_trial_path: new_trial_path(glm_source: 'gitlab.com', glm_content: 'chat panel'),
              trial_duration: 30
            })
          end
        end

        context 'when within a project owned by a user' do
          let(:source) { project_owned_by_user }

          it 'returns the correct data' do
            is_expected.to eq({
              new_trial_path: new_trial_path(glm_source: 'gitlab.com', glm_content: 'chat panel'),
              trial_duration: 30
            })
          end
        end

        context 'when within a project owned by a group' do
          let(:source) { project_owned_by_group }

          it 'returns the correct data' do
            is_expected.to eq({
              new_trial_path: new_trial_path(namespace_id: source.root_ancestor.id, glm_source: 'gitlab.com',
                glm_content: 'chat panel'),
              trial_duration: 30
            })
          end
        end

        context 'when within a group' do
          let(:source) { group }

          it 'returns the correct data' do
            is_expected.to eq({
              new_trial_path: new_trial_path(namespace_id: source.root_ancestor.id, glm_source: 'gitlab.com',
                glm_content: 'chat panel'),
              trial_duration: 30,
              namespace_type: 'Group'
            })
          end
        end

        context 'when the trial duration is not the default' do
          before do
            stub_saas_features(subscriptions_trials: true)
            allow_next_instance_of(GitlabSubscriptions::TrialDurationService) do |service|
              allow(service).to receive(:execute).and_return(20)
            end
          end

          it 'returns the correct data' do
            is_expected.to eq({
              new_trial_path: new_trial_path(glm_source: 'gitlab.com', glm_content: 'chat panel'),
              trial_duration: 20
            })
          end
        end
      end
    end

    context 'on Self-Managed' do
      let(:source) { group }
      let(:manage_subscription?) { false }

      before do
        allow(helper).to receive_messages(self_managed_new_trial_url: 'subscription_portal_trial_url')
        allow(Ability).to receive(:allowed?).with(user, :manage_subscription).and_return(manage_subscription?)
      end

      context 'when user cannot start a trial' do
        it 'returns the correct data' do
          is_expected.to eq({
            namespace_type: 'Group'
          })
        end
      end

      context 'when user can start a trial' do
        let(:manage_subscription?) { true }

        it 'returns the correct data' do
          is_expected.to eq({
            new_trial_path: 'subscription_portal_trial_url',
            trial_duration: 30,
            namespace_type: 'Group'
          })
        end
      end
    end
  end

  describe '#agentic_unavailable_message' do
    let(:user) { build(:user) }
    let(:container) { build(:project) }
    let(:allowed) { false }
    let(:enablement_type) { nil }
    let(:duo_response) do
      instance_double(Ai::UserAuthorizable::Response, enablement_type: enablement_type, allowed?: allowed)
    end

    def expect_generic_message(result)
      expect(result).to eq(
        "You don't currently have access to Duo Chat, please contact your GitLab administrator."
      )
    end

    before do
      allow(user).to receive(:allowed_to_use).and_return(duo_response)
    end

    context 'when agentic is available' do
      it 'returns nil' do
        result = helper.agentic_unavailable_message(user, container, true)

        expect(result).to be_nil
      end
    end

    context 'when agentic is not available' do
      context 'when container is present' do
        let(:allowed) { false }

        it 'returns nil' do
          result = helper.agentic_unavailable_message(user, container, false)

          expect(result).to be_nil
        end
      end

      context 'when container is nil' do
        let(:allowed) { true }

        def expect_unavailable_message(result)
          expect(result).to include('Duo Agentic Chat is not available at the moment in this page.')
          expect(result).to include('Default GitLab Duo namespace')
          expect(result).to include(
            '/-/profile/preferences#user_duo_default_namespace_id'
          )
        end

        context 'with duo_pro enablement' do
          let(:enablement_type) { 'duo_pro' }

          it 'links to preference page' do
            result = helper.agentic_unavailable_message(user, nil, false)

            expect_unavailable_message(result)
          end
        end

        context 'with duo_core enablement' do
          let(:enablement_type) { 'duo_core' }

          it 'returns project page message' do
            result = helper.agentic_unavailable_message(user, nil, false)

            expect_unavailable_message(result)
          end
        end

        context 'when user is not allowed chat at all' do
          it 'returns generic message' do
            result = helper.agentic_unavailable_message(user, nil, false)

            expect(result).to be_nil
          end
        end
      end
    end
  end

  describe '#force_agentic_mode_for_core_duo_users?' do
    let(:user) { build(:user) }
    let(:allowed) { true }
    let(:enablement_type) { 'duo_pro' }
    let(:duo_response) do
      instance_double(Ai::UserAuthorizable::Response, enablement_type: enablement_type, allowed?: allowed)
    end

    before do
      allow(user).to receive(:allowed_to_use)
                       .with(:agentic_chat, { unit_primitive_name: :duo_chat })
                       .and_return(duo_response)
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(no_duo_classic_for_duo_core_users: false)
      end

      it 'returns false regardless of enablement type' do
        expect(helper.force_agentic_mode_for_core_duo_users?(user)).to be(false)
      end

      context 'with duo_core enablement' do
        let(:enablement_type) { 'duo_core' }

        it 'returns false' do
          expect(helper.force_agentic_mode_for_core_duo_users?(user)).to be(false)
        end
      end
    end

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(no_duo_classic_for_duo_core_users: true)
      end

      context 'when user has duo_pro enablement' do
        let(:enablement_type) { 'duo_pro' }

        it 'returns false' do
          expect(helper.force_agentic_mode_for_core_duo_users?(user)).to be(false)
        end
      end

      context 'when user has duo_enterprise enablement' do
        let(:enablement_type) { 'duo_enterprise' }

        it 'returns false' do
          expect(helper.force_agentic_mode_for_core_duo_users?(user)).to be(false)
        end
      end

      context 'when user has duo_core enablement' do
        let(:enablement_type) { 'duo_core' }

        it 'returns true' do
          expect(helper.force_agentic_mode_for_core_duo_users?(user)).to be(true)
        end
      end

      context 'when user is not allowed to use duo_chat' do
        let(:allowed) { false }

        it 'returns false' do
          expect(helper.force_agentic_mode_for_core_duo_users?(user)).to be(false)
        end
      end
    end
  end
end
