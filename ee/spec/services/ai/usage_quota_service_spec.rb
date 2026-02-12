# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UsageQuotaService, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let(:ai_feature) { :duo_chat }

  describe '#usage_quota_check' do
    let(:event_type) { :rails_on_ui_check }
    let(:feature_metadata) do
      Gitlab::SubscriptionPortal::FeatureMetadata::Feature.new(
        feature_qualified_name: 'dap_feature_legacy',
        feature_ai_catalog_item: nil
      )
    end

    before do
      allow(::Gitlab::SubscriptionPortal::FeatureMetadata)
        .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)
    end

    context 'when running on GitLab.com', :saas do
      shared_examples 'falling back to default namespace' do
        context 'when default namespace selected by user' do
          let_it_be(:default_namespace) { create(:group) }

          before do
            allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(default_namespace)
          end

          it 'calls portal with default namespace, dap_feature_legacy metadata, and rails_on_ui_check event type' do
            expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
              .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)
            expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
              :rails_on_ui_check,
              feature_metadata,
              user_id: user.id,
              root_namespace_id: default_namespace.id,
              plan_key: 'free'
            )

            service_call
          end
        end

        it 'returns error' do
          expect(service_call).to be_error
          expect(service_call[:reason]).to eq(:namespace_missing)
        end
      end

      subject(:service_call) { described_class.new(ai_feature: ai_feature, user: user).execute }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when namespace is not provided' do
        it_behaves_like 'falling back to default namespace'
      end

      context 'when namespace is provided' do
        subject(:service_call) { described_class.new(ai_feature: ai_feature, user: user, namespace: namespace).execute }

        let_it_be(:root_namespace) { create(:group_with_plan, plan: :premium_plan) }
        let_it_be(:namespace) { create(:group, parent: root_namespace) }

        context 'when the user can invoke the feature in the given namespace' do
          before do
            allow(user).to receive(:allowed_by_namespace_ids).with(ai_feature).and_return([root_namespace.id])
          end

          context 'when the user is a gitlab team member' do
            before do
              stub_feature_flags(enable_quota_check_for_team_members: false)
              allow(user).to receive(:gitlab_team_member?).and_return(true)
            end

            it 'is successful' do
              expect(::Gitlab::SubscriptionPortal::Client).not_to receive(:verify_usage_quota)
              expect(service_call).to be_success
            end

            context 'when enable_quota_check_for_team_members is enabled' do
              before do
                stub_feature_flags(enable_quota_check_for_team_members: true)
              end

              it 'is verifies usage' do
                expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota)
                expect(service_call).to be_success
              end
            end
          end

          context 'when usage quota is available' do
            before do
              allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
                :rails_on_ui_check,
                feature_metadata,
                user_id: user.id,
                root_namespace_id: root_namespace.id,
                plan_key: 'premium'
              ).and_return({ success: true })
            end

            it 'calls portal with provided namespace, dap_feature_legacy metadata, and rails_on_ui_check event type' do
              expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
                .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)
              expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
                :rails_on_ui_check,
                feature_metadata,
                user_id: user.id,
                root_namespace_id: root_namespace.id,
                plan_key: 'premium'
              )

              expect(service_call).to be_success
            end
          end

          context 'when usage quota is not available' do
            before do
              allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
                :rails_on_ui_check,
                feature_metadata,
                user_id: user.id,
                root_namespace_id: root_namespace.id,
                plan_key: 'premium'
              ).and_return({ success: false, data: { errors: "HTTP status code: 402" } }.with_indifferent_access)
            end

            it 'calls portal with provided namespace, dap_feature_legacy metadata, and rails_on_ui_check event type' do
              expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
                .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)
              expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
                :rails_on_ui_check,
                feature_metadata,
                user_id: user.id,
                root_namespace_id: root_namespace.id,
                plan_key: 'premium'
              )

              expect(service_call).to be_error
              expect(service_call[:reason]).to eq(:usage_quota_exceeded)
            end
          end
        end

        context 'when the user is not allowed to invoke the feature in the given namespace' do
          it_behaves_like 'falling back to default namespace'
        end
      end
    end

    context 'when running on self-hosted instance' do
      let(:plan_key) { '' }
      let(:unique_instance_id) { 'instance_id' }
      let(:real_unique_instance_id) { 'uniq_instance_id' }

      let(:params) do
        [
          :rails_on_ui_check,
          feature_metadata,
          {
            user_id: user.id,
            unique_instance_id: unique_instance_id,
            plan_key: plan_key
          }
        ]
      end

      subject(:service_call) { described_class.new(ai_feature: ai_feature, user: user).execute }

      before do
        allow(::Gitlab::GlobalAnonymousId)
          .to receive_messages(instance_id: unique_instance_id, instance_uuid: real_unique_instance_id)
      end

      context 'when on paid license' do
        before do
          create_current_license
        end

        it 'calls portal with instance id, dap_feature_legacy metadata, and rails_on_ui_check event type' do
          expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
            .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(*params)

          service_call
        end
      end

      context 'when on trial' do
        let(:plan_key) { 'true' }
        let(:unique_instance_id) { real_unique_instance_id }

        before do
          create_current_license(:trial)
        end

        it 'calls portal with instance id, dap_feature_legacy metadata, and rails_on_ui_check event type' do
          expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
            .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(*params)

          service_call
        end
      end

      context 'when no license exists', :without_license do
        it 'calls portal with instance id, dap_feature_legacy metadata, and rails_on_ui_check event type' do
          expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
            .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(*params)

          service_call
        end
      end
    end

    context 'when custom event_type is provided' do
      subject(:service_call) do
        described_class.new(ai_feature: ai_feature, user: user, event_type: :custom_event).execute
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(create(:group, id: 999))
        allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).and_return({ success: true })
      end

      it 'uses the custom event_type instead of default rails_on_ui_check' do
        expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
          .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)
        expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
          :custom_event,
          feature_metadata,
          user_id: user.id,
          root_namespace_id: 999,
          plan_key: 'free'
        )

        service_call
      end
    end

    context 'when user is not present' do
      subject(:service_call) { described_class.new(ai_feature: ai_feature, user: nil).execute }

      it "returns error that user is not present" do
        expect(service_call).to be_error
        expect(service_call[:reason]).to eq(:user_missing)
      end
    end

    context 'when subscription portal call results in error' do
      subject(:service_call) { described_class.new(ai_feature: ai_feature, user: create(:project)).execute }

      before do
        allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).and_raise(StandardError.new)
      end

      it "does not block user access" do
        is_expected.to be_success
      end
    end
  end
end
