# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Layout/LineLength -- list of params is too long
RSpec.shared_examples 'renders model deprecation alert for one deprecated model' do |model_name, deprecation_date, removal_version|
  it 'renders a deprecation alert with the correct title' do
    expect(page).to have_selector('[data-testid="ai-model-deprecation-alert"]')
    expect(page).to have_content('Model scheduled for removal')
  end

  it 'renders the single model deprecation message' do
    expected_message = "#{model_name} was deprecated on #{deprecation_date} and will stop working after GitLab removes it in #{removal_version}. Please change to an alternative model"
    expect(page).to have_content(expected_message)
  end
end
# rubocop:enable Layout/LineLength

RSpec.shared_examples 'renders model deprecation alert for multiple deprecated models' do |expected_models|
  it 'renders a deprecation alert with the correct title' do
    expect(page).to have_selector('[data-testid="ai-model-deprecation-alert"]')
    expect(page).to have_content('Models scheduled for removal')
  end

  it 'renders the multiple models deprecation message' do
    expect(page).to have_content(
      'The following models have been deprecated and will stop working after GitLab removes them'
    )
  end

  it 'renders a list with all deprecated models' do
    expect(page).to have_selector('ul li', count: expected_models.count)

    expected_models.each do |model|
      expect(page).to have_content(
        "#{model['model_name']} (deprecated #{model['deprecation_date']} - Removes in: #{model['removal_version']})"
      )
    end
  end
end

RSpec.describe Namespaces::AiModelDeprecationsAlertComponent, :saas, feature_category: :duo_chat do
  include_context 'with mocked ::Ai::ModelSelection::FetchModelDefinitionsService'

  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:subgroup) { build_stubbed(:group, parent: group) }

  subject(:component) { described_class.new(user: user, group: group) }

  context 'when on group settings' do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    context 'when group is a top-level group and user is owner of this group' do
      before do
        allow(user).to receive(:can?).with(user, :owner_access, group).and_return(true)
      end

      context 'when a single deprecated model is selected' do
        let_it_be(:namespace_setting) do
          build_stubbed(:ai_namespace_feature_setting,
            namespace: group,
            feature: :review_merge_request,
            offered_model_ref: 'claude-sonnet-3-7',
            model_definitions: fetch_model_definitions_example)
        end

        before do
          allow(::Ai::ModelSelection::NamespaceFeatureSetting)
            .to receive_message_chain(:for_namespace, :non_default)
            .and_return([namespace_setting])

          render_inline(component)
        end

        # rubocop:disable Layout/LineLength -- message is too long
        it_behaves_like 'renders model deprecation alert for one deprecated model', 'Claude Sonnet 3.7', '2025-10-28', '18.8'
        # rubocop:enable Layout/LineLength

        it 'renders the change model button' do
          expect(page).to have_link('Change model', href: group_settings_gitlab_duo_model_selection_index_path(group))
        end
      end

      context 'when multiple deprecated models are selected' do
        let_it_be(:model_definitions_with_multiple_deprecated) do
          fetch_model_definitions_example.merge(
            'models' => fetch_model_definitions_example['models'] + [
              { 'name' => 'GPT-4 Deprecated', 'identifier' => 'gpt-4-deprecated',
                'deprecation' => { 'deprecation_date' => '2025-11-15', 'removal_version' => '18.9' } }
            ]
          )
        end

        let_it_be(:namespace_setting_1) do
          build_stubbed(:ai_namespace_feature_setting,
            namespace: group,
            feature: :review_merge_request,
            offered_model_ref: 'claude-sonnet-3-7',
            model_definitions: model_definitions_with_multiple_deprecated)
        end

        let_it_be(:namespace_setting_2) do
          build_stubbed(:ai_namespace_feature_setting,
            namespace: group,
            feature: :duo_chat,
            offered_model_ref: 'gpt-4-deprecated',
            model_definitions: model_definitions_with_multiple_deprecated)
        end

        before do
          allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.success(payload: model_definitions_with_multiple_deprecated)
            )
          end

          allow(::Ai::ModelSelection::NamespaceFeatureSetting)
            .to receive_message_chain(:for_namespace, :non_default)
            .and_return([namespace_setting_1, namespace_setting_2])

          render_inline(component)
        end

        include_examples 'renders model deprecation alert for multiple deprecated models', [
          { 'model_name' => 'Claude Sonnet 3.7', 'deprecation_date' => '2025-10-28', 'removal_version' => '18.8' },
          { 'model_name' => 'GPT-4 Deprecated', 'deprecation_date' => '2025-11-15', 'removal_version' => '18.9' }
        ]

        it 'renders the change model button' do
          expect(page).to have_link('Change model', href: group_settings_gitlab_duo_model_selection_index_path(group))
        end
      end
    end

    context 'when a no deprecated model is selected' do
      let_it_be(:namespace_setting) do
        build_stubbed(:ai_namespace_feature_setting,
          namespace: group,
          feature: :review_merge_request,
          offered_model_ref: 'claude-sonnet',
          model_definitions: fetch_model_definitions_example)
      end

      before do
        allow(::Ai::ModelSelection::NamespaceFeatureSetting)
          .to receive_message_chain(:for_namespace, :non_default)
          .and_return([namespace_setting])

        render_inline(component)
      end

      it 'does not render the deprecation alert' do
        render_inline(component)

        expect(page).not_to have_selector('[data-testid="ai-model-deprecation-alert"]')
      end
    end

    context 'when user is not an owner of the group' do
      before do
        allow(user).to receive(:can?).with(user, :owner_access, group).and_return(false)
      end

      it 'does not render the deprecation alert' do
        render_inline(component)

        expect(page).not_to have_selector('[data-testid="ai-model-deprecation-alert"]')
      end
    end

    context 'when group is not a top-level group' do
      subject(:component) { described_class.new(user: user, group: subgroup) }

      before do
        allow(user).to receive(:can?).with(user, :owner_access, group).and_return(true)
      end

      it 'does not render the deprecation alert' do
        render_inline(component)

        expect(page).not_to have_selector('[data-testid="ai-model-deprecation-alert"]')
      end
    end
  end

  context 'when on instance settings' do
    before do
      stub_saas_features(gitlab_com_subscriptions: false)
    end

    context 'when a single deprecated model is selected' do
      let_it_be(:instance_setting) do
        build_stubbed(:instance_model_selection_feature_setting,
          feature: :review_merge_request,
          offered_model_ref: 'claude-sonnet-3-7',
          model_definitions: fetch_model_definitions_example)
      end

      before do
        allow(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
          .to receive(:non_default)
          .and_return([instance_setting])

        render_inline(component)
      end

      # rubocop:disable Layout/LineLength -- message is too long
      it_behaves_like 'renders model deprecation alert for one deprecated model', 'Claude Sonnet 3.7', '2025-10-28', '18.8'
      # rubocop:enable Layout/LineLength

      it 'renders the change model button' do
        expect(page).to have_link('Change model', href: admin_gitlab_duo_path)
      end
    end

    context 'when multiple deprecated models are selected' do
      let_it_be(:model_definitions_with_multiple_deprecated) do
        fetch_model_definitions_example.merge(
          'models' => fetch_model_definitions_example['models'] + [
            { 'name' => 'GPT-4 Deprecated', 'identifier' => 'gpt-4-deprecated',
              'deprecation' => { 'deprecation_date' => '2025-11-15', 'removal_version' => '18.9' } }
          ]
        )
      end

      let_it_be(:instance_setting_1) do
        build_stubbed(:instance_model_selection_feature_setting,
          feature: :review_merge_request,
          offered_model_ref: 'claude-sonnet-3-7',
          model_definitions: model_definitions_with_multiple_deprecated)
      end

      let_it_be(:instance_setting_2) do
        build_stubbed(:instance_model_selection_feature_setting,
          feature: :duo_chat,
          offered_model_ref: 'gpt-4-deprecated',
          model_definitions: model_definitions_with_multiple_deprecated)
      end

      before do
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: model_definitions_with_multiple_deprecated)
          )
        end

        allow(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
          .to receive(:non_default)
          .and_return([instance_setting_1, instance_setting_2])

        render_inline(component)
      end

      include_examples 'renders model deprecation alert for multiple deprecated models', [
        { 'model_name' => 'Claude Sonnet 3.7', 'deprecation_date' => '2025-10-28', 'removal_version' => '18.8' },
        { 'model_name' => 'GPT-4 Deprecated', 'deprecation_date' => '2025-11-15', 'removal_version' => '18.9' }
      ]

      it 'renders the change model button' do
        expect(page).to have_link('Change model', href: admin_gitlab_duo_path)
      end
    end

    context 'when a no deprecated model is selected' do
      let_it_be(:instance_setting) do
        build_stubbed(:instance_model_selection_feature_setting,
          feature: :review_merge_request,
          offered_model_ref: 'claude-sonnet',
          model_definitions: fetch_model_definitions_example)
      end

      before do
        allow(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
          .to receive(:non_default)
          .and_return([instance_setting])

        render_inline(component)
      end

      it 'does not render the deprecation alert' do
        render_inline(component)

        expect(page).not_to have_selector('[data-testid="ai-model-deprecation-alert"]')
      end
    end
  end

  describe '#fetch_deprecated_models' do
    subject(:fetch_deprecated_models) { component.send(:fetch_deprecated_models) }

    context 'when on SaaS with group context' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'calls FetchModelDefinitionsService with group as model_selection_scope' do
        expect_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService, user,
          model_selection_scope: group) do |service|
          expect(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: fetch_model_definitions_example)
          )
        end

        fetch_deprecated_models
      end

      it 'returns deprecated models when service succeeds' do
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: fetch_model_definitions_example)
          )
        end

        result = fetch_deprecated_models

        expect(result).to be_an(Array)
        expect(result.size).to eq(1)
        expect(result.first['identifier']).to eq('claude-sonnet-3-7')
        expect(result.first['name']).to eq('Claude Sonnet 3.7')
        expect(result.first['deprecation']).to include('deprecation_date' => '2025-10-28', 'removal_version' => '18.8')
      end

      it 'returns empty array when service fails' do
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Failed to fetch models')
          )
        end

        expect(fetch_deprecated_models).to eq([])
      end

      it 'returns empty array when service returns nil' do
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(nil)
        end

        expect(fetch_deprecated_models).to eq([])
      end
    end

    context 'when on self-managed instance' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'calls FetchModelDefinitionsService with nil model_selection_scope' do
        expect_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService, user,
          model_selection_scope: nil) do |service|
          expect(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: fetch_model_definitions_example)
          )
        end

        fetch_deprecated_models
      end

      it 'returns deprecated models when service succeeds' do
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: fetch_model_definitions_example)
          )
        end

        result = fetch_deprecated_models

        expect(result).to be_an(Array)
        expect(result.size).to eq(1)
        expect(result.first['identifier']).to eq('claude-sonnet-3-7')
      end
    end
  end
end
