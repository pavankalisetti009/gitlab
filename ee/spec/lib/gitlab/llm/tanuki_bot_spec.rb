# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::TanukiBot, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  describe '.enabled_for?', :use_clean_rails_redis_caching do
    let_it_be_with_reload(:group) { create(:group) }
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }

    context 'when user present and container is not present' do
      where(:allowed, :result) do
        [
          [true, true],
          [false, false]
        ]
      end

      with_them do
        before do
          allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:user).with(user: user)
                                                                            .and_return(authorizer_response)
        end

        it 'returns correct result' do
          expect(described_class.enabled_for?(user: user)).to be(result)
        end
      end
    end

    context 'when user and container are both present' do
      where(:allowed, :result) do
        [
          [true, true],
          [false, false]
        ]
      end

      with_them do
        before do
          allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:container).with(user: user, container: group)
                                                                                 .and_return(authorizer_response)
        end

        it 'returns correct result' do
          expect(described_class.enabled_for?(user: user, container: group)).to be(result)
        end
      end
    end

    context 'when user is not present' do
      it 'returns false' do
        expect(described_class.enabled_for?(user: nil)).to be(false)
      end
    end
  end

  describe '.agentic_mode_available?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:group) { create(:group) }

    context 'with a persisted project' do
      context 'when user can access duo agentic chat for project' do
        before do
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, project).and_return(true)
        end

        it 'returns true' do
          expect(described_class.agentic_mode_available?(user: user, project: project, group: nil)).to be(true)
        end
      end

      context 'when user cannot access duo agentic chat for project' do
        before do
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, project).and_return(false)
        end

        it 'returns false' do
          expect(described_class.agentic_mode_available?(user: user, project: project, group: nil)).to be(false)
        end
      end
    end

    context 'with a persisted group' do
      context 'when user can access duo agentic chat for group' do
        before do
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, group).and_return(true)
        end

        it 'returns true' do
          expect(described_class.agentic_mode_available?(user: user, project: nil, group: group)).to be(true)
        end
      end

      context 'when user cannot access duo agentic chat for group' do
        before do
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, group).and_return(false)
        end

        it 'returns false' do
          expect(described_class.agentic_mode_available?(user: user, project: nil, group: group)).to be(false)
        end
      end
    end

    context 'with both project and group present' do
      context 'when user can access duo agentic chat for project' do
        before do
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, project).and_return(true)
        end

        it 'prioritizes project and returns true' do
          expect(described_class.agentic_mode_available?(user: user, project: project, group: group)).to be(true)
        end
      end

      context 'when user cannot access duo agentic chat for project but can for group' do
        before do
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, project).and_return(false)
          allow(user).to receive(:can?).with(:access_duo_agentic_chat, group).and_return(true)
        end

        it 'prioritizes project and returns false' do
          expect(described_class.agentic_mode_available?(user: user, project: project, group: group)).to be(false)
        end
      end
    end

    context 'with non-persisted project' do
      let(:non_persisted_project) { build(:project) }

      before do
        allow(user).to receive(:can?).with(:access_duo_agentic_chat, group).and_return(true)
      end

      it 'falls back to group check' do
        expect(described_class.agentic_mode_available?(user: user, project: non_persisted_project,
          group: group)).to be(true)
      end
    end

    context 'with non-persisted group' do
      let(:non_persisted_group) { build(:group) }

      it 'returns false' do
        expect(described_class.agentic_mode_available?(user: user, project: nil,
          group: non_persisted_group)).to be(false)
      end
    end

    context 'with nil project and nil group' do
      it 'returns false' do
        expect(described_class.agentic_mode_available?(user: user, project: nil, group: nil)).to be(false)
      end
    end
  end

  describe '.show_breadcrumbs_entry_point' do
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }

    before do
      allow(described_class).to receive(:chat_enabled?).with(user)
                                                       .and_return(ai_features_enabled_for_user)
      allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:user).with(user: user)
                                                                        .and_return(authorizer_response)
    end

    where(:ai_features_enabled_for_user, :allowed, :duo_chat_access) do
      [
        [true, true, true],
        [true, false, false],
        [false, true, false],
        [false, false, false]
      ]
    end

    with_them do
      it 'shows button in correct cases' do
        expect(described_class.show_breadcrumbs_entry_point?(user: user)).to be(duo_chat_access)
      end
    end
  end

  describe '.chat_disabled_reason' do
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }
    let(:container) { build_stubbed(:group) }

    before do
      allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer)
        .to receive(:container).with(container: container, user: user)
                               .and_return(authorizer_response)
    end

    context 'when chat is allowed' do
      let(:allowed) { true }

      it 'returns nil' do
        expect(described_class.chat_disabled_reason(user: user, container: container)).to be_nil
      end
    end

    context 'when chat is not allowed' do
      let(:allowed) { false }

      context 'with a group' do
        it 'returns group' do
          expect(described_class.chat_disabled_reason(user: user, container: container)).to be(:group)
        end
      end

      context 'with a project' do
        let(:container) { build_stubbed(:project) }

        it 'returns project' do
          expect(described_class.chat_disabled_reason(user: user, container: container)).to be(:project)
        end
      end

      context 'without a container' do
        let(:container) { nil }

        it 'returns nil' do
          expect(described_class.chat_disabled_reason(user: user, container: container)).to be_nil
        end
      end
    end
  end

  describe '.resource_id' do
    let(:issue) { build_stubbed(:issue) }

    context 'with current context including resource_id' do
      before do
        Gitlab::ApplicationContext.push(ai_resource: issue.to_global_id)
      end

      it 'returns the ai_resource from the current context' do
        expect(described_class.resource_id).to eq(issue.to_global_id)
      end
    end

    context 'with current context not including resource_id' do
      it 'returns nil when ai_resource is not present in the context' do
        expect(described_class.resource_id).to be_nil
      end
    end
  end

  describe '.project_id' do
    let_it_be(:project) { create(:project) }

    context 'with current context including project_id' do
      before do
        ::Gitlab::ApplicationContext.push(project: project)
      end

      it 'returns the global ID of the project when found' do
        expect(described_class.project_id).to eq(project.to_global_id)
      end
    end

    context 'when project is not found' do
      before do
        ::Gitlab::ApplicationContext.push(project: 'non_existent_project')
      end

      it 'returns nil' do
        expect(described_class.project_id).to be_nil
      end
    end

    context 'when project is not present in the context' do
      it 'returns nil' do
        expect(described_class.project_id).to be_nil
      end
    end
  end

  describe '.namespace' do
    let_it_be(:group) { create(:group) }

    context 'when root_namespace is present in context' do
      it 'returns the group found by full_path' do
        result = ::Gitlab::ApplicationContext.with_raw_context(root_namespace: group.full_path) do
          described_class.namespace
        end

        expect(result).to eq(group)
      end
    end

    context 'when root_namespace is not present in context' do
      it 'returns nil' do
        expect(described_class.namespace).to be_nil
      end
    end

    context 'when root_namespace path does not exist' do
      it 'returns nil' do
        result = ::Gitlab::ApplicationContext.with_raw_context(root_namespace: 'non_existent_path') do
          described_class.namespace
        end

        expect(result).to be_nil
      end
    end

    context 'when root_namespace is empty string' do
      it 'returns nil' do
        result = ::Gitlab::ApplicationContext.with_raw_context(root_namespace: '') do
          described_class.namespace
        end

        expect(result).to be_nil
      end
    end
  end

  describe '.default_duo_namespace' do
    let(:default_namespace) { create(:group) }

    it 'returns nil when user is not present' do
      expect(described_class.default_duo_namespace(user: nil)).to be_nil
    end

    it 'returns the default duo namespace from user preference' do
      allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(default_namespace)

      expect(described_class.default_duo_namespace(user: user)).to eq(default_namespace)
    end

    it 'returns nil when user preference has no default namespace' do
      allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(nil)

      expect(described_class.default_duo_namespace(user: user)).to be_nil
    end
  end

  describe '.root_namespace_id' do
    let_it_be(:group) { create(:group) }
    let_it_be(:default_group) { create(:group) }

    context 'with current context including root_namespace' do
      let(:result) do
        ::Gitlab::ApplicationContext.with_raw_context(root_namespace: group.full_path) do
          described_class.root_namespace_id(user: user)
        end
      end

      it 'returns the global ID of the root namespace when found' do
        expect(result).to eq(group.to_global_id)
      end
    end

    context 'when root_namespace is not found in context' do
      let(:result) do
        ::Gitlab::ApplicationContext.with_raw_context(root_namespace: 'non_existent_namespace') do
          described_class.root_namespace_id(user: user)
        end
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when root_namespace is not present in the context' do
      context 'when user has a default duo namespace' do
        before do
          allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(default_group)
        end

        it 'returns the global ID of the default namespace' do
          expect(described_class.root_namespace_id(user: user)).to eq(default_group.to_global_id)
        end
      end

      context 'when user has no default duo namespace' do
        before do
          allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(nil)
        end

        it 'returns nil' do
          expect(described_class.root_namespace_id(user: user)).to be_nil
        end
      end
    end
  end

  describe '.user_model_selection_enabled?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:default_group) { create(:group) }

    context 'with current context including root_namespace' do
      subject(:result) do
        ::Gitlab::ApplicationContext.with_raw_context(root_namespace: root_namespace) do
          described_class.user_model_selection_enabled?(user: user)
        end
      end

      context 'when root namespace is not found' do
        let(:root_namespace) { 'non_existent_namespace' }

        it { is_expected.to be_falsey }
      end

      context 'when root_namespace is found' do
        let(:root_namespace) { group.full_path }

        context 'when duo_agent_platform_model_selection feature flag is disabled' do
          before do
            stub_feature_flags(duo_agent_platform_model_selection: false)
          end

          it { is_expected.to be_falsey }
        end

        context 'when ai_user_model_switching feature flag is disabled' do
          before do
            stub_feature_flags(ai_user_model_switching: false)
          end

          it { is_expected.to be_falsey }
        end

        context 'when duo_agent_platform_model_selection feature flag is enabled' do
          before do
            stub_feature_flags(duo_agent_platform_model_selection: true)
          end

          context 'when ai_user_model_switching feature flag is enabled' do
            before do
              stub_feature_flags(ai_user_model_switching: true)

              allow_next_instance_of(Ai::FeatureSettingSelectionService) do |service|
                allow(service).to receive(:execute).and_return(service_response)
              end
            end

            context 'when the feature setting returns ai_feature_setting payload' do
              let(:payload) { build(:ai_feature_setting, feature: :duo_agent_platform) }
              let(:service_response) { ServiceResponse.success(payload: payload) }

              it { is_expected.to be_falsey }
            end

            context 'when the feature setting returns instance_model_selection_feature_setting payload' do
              let(:payload) { build(:instance_model_selection_feature_setting, feature: :duo_agent_platform) }
              let(:service_response) { ServiceResponse.success(payload: payload) }

              it { is_expected.to be_truthy }
            end

            context 'when the feature setting returns ai_namespace_feature_setting payload' do
              let(:payload) { build(:ai_namespace_feature_setting, namespace: group, feature: :duo_agent_platform) }
              let(:service_response) { ServiceResponse.success(payload: payload) }

              it { is_expected.to be_truthy }
            end

            context 'when the feature setting service returns an error' do
              let(:service_response) { ServiceResponse.error(message: "error!") }

              it { is_expected.to be_falsey }
            end
          end
        end
      end
    end

    context 'when root_namespace is not present in the context' do
      context 'when user has a default duo namespace' do
        before do
          allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(default_group)

          allow_next_instance_of(Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(service_response)
          end
        end

        context 'when duo_agent_platform_model_selection feature flag is disabled' do
          before do
            stub_feature_flags(duo_agent_platform_model_selection: false)
          end

          it 'returns false' do
            expect(described_class.user_model_selection_enabled?(user: user)).to be(false)
          end
        end

        context 'when ai_user_model_switching feature flag is disabled' do
          before do
            stub_feature_flags(ai_user_model_switching: false)
          end

          it 'returns false' do
            expect(described_class.user_model_selection_enabled?(user: user)).to be(false)
          end
        end

        context 'when all feature flags are enabled' do
          context 'when the feature setting returns instance_model_selection_feature_setting payload' do
            let(:payload) { build(:instance_model_selection_feature_setting, feature: :duo_agent_platform) }
            let(:service_response) { ServiceResponse.success(payload: payload) }

            it 'returns true using default namespace' do
              expect(described_class.user_model_selection_enabled?(user: user)).to be(true)
            end
          end

          context 'when the feature setting returns ai_namespace_feature_setting payload' do
            let(:payload) do
              build(:ai_namespace_feature_setting, namespace: default_group, feature: :duo_agent_platform)
            end

            let(:service_response) { ServiceResponse.success(payload: payload) }

            it 'returns true using default namespace' do
              expect(described_class.user_model_selection_enabled?(user: user)).to be(true)
            end
          end

          context 'when the feature setting service returns an error' do
            let(:service_response) { ServiceResponse.error(message: "error!") }

            it 'returns false' do
              expect(described_class.user_model_selection_enabled?(user: user)).to be(false)
            end
          end

          context 'when the feature setting service returns success with nil payload' do
            let(:service_response) { ServiceResponse.success(payload: nil) }

            it 'returns false' do
              expect(described_class.user_model_selection_enabled?(user: user)).to be(false)
            end
          end
        end
      end

      context 'when user has no default duo namespace' do
        before do
          allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(nil)
        end

        it 'returns false' do
          expect(described_class.user_model_selection_enabled?(user: user)).to be(false)
        end
      end
    end
  end
end
