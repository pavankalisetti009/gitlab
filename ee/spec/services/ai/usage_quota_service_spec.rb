# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UsageQuotaService, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let(:ai_feature) { :duo_chat }

  describe '#usage_quota_check' do
    context 'when running on GitLab.com' do
      shared_examples 'falling back to default namespace' do
        context 'when default namespace selected by user' do
          let_it_be(:default_namespace) { create(:group) }

          before do
            allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(default_namespace)
          end

          it 'calls portal with default namespace' do
            expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
              user_id: user.id,
              root_namespace_id: default_namespace.id
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

        let_it_be(:namespace) { create(:group) }

        context 'when the user can invoke the feature in the given namespace' do
          before do
            allow(user).to receive(:allowed_by_namespace_ids).with(ai_feature).and_return([namespace.id])
          end

          context 'when usage quota is available' do
            before do
              allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
                user_id: user.id,
                root_namespace_id: namespace.id
              ).and_return({ success: true })
            end

            it 'calls portal with provided namespace and returns success' do
              expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
                user_id: user.id,
                root_namespace_id: namespace.id
              )

              expect(service_call).to be_success
            end
          end

          context 'when usage quota is not available' do
            before do
              allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
                user_id: user.id,
                root_namespace_id: namespace.id
              ).and_return({ success: false })
            end

            it 'calls portal with provided namespace and returns error' do
              expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
                user_id: user.id,
                root_namespace_id: namespace.id
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
      subject(:service_call) { described_class.new(ai_feature: ai_feature, user: user).execute }

      before do
        allow(::Gitlab::GlobalAnonymousId).to receive(:instance_uuid).and_return("instance_id")
      end

      it 'calls portal with instance id' do
        expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(
          user_id: user.id,
          unique_instance_id: "instance_id"
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

    context 'when feature flag is disabled' do
      subject(:service_call) { described_class.new(ai_feature: ai_feature, user: nil).execute }

      before do
        stub_feature_flags(usage_quota_left_check: false)
      end

      it { is_expected.to be_success }
    end

    context 'when wrong params are used' do
      subject(:service_call) { described_class.new(ai_feature: ai_feature, user: create(:project)).execute }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it "returns general error" do
        expect(service_call).to be_error
        expect(service_call[:reason]).to eq(:service_error)
      end
    end
  end
end
