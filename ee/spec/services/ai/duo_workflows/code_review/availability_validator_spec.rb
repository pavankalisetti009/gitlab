# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::AvailabilityValidator, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: project) }

  describe '#available?' do
    subject(:available) { validator.available? }

    shared_examples 'duo features disabled check' do
      context 'when resource does not have duo_features_enabled' do
        before do
          case resource
          when Project
            resource.project_setting.update!(duo_features_enabled: false)
          when Group
            resource.namespace_settings.update!(duo_features_enabled: false)
          end
        end

        it 'returns false' do
          expect(available).to be false
        end
      end
    end

    shared_examples 'duo_foundational_flows_enabled check' do
      context 'when duo_foundational_flows_enabled is false' do
        before do
          case resource
          when Project
            resource.project_setting.update!(duo_foundational_flows_enabled: false)
          when Group
            resource.namespace_settings.update!(duo_foundational_flows_enabled: false)
          end
        end

        it 'returns false' do
          expect(available).to be false
        end
      end
    end

    shared_examples 'Duo Enterprise behavior' do
      before do
        add_on_purchase_relation = instance_double(ActiveRecord::Relation, exists?: true)
        allow(::GitlabSubscriptions::AddOnPurchase)
          .to receive(:for_active_add_ons)
          .with([:duo_enterprise], user)
          .and_return(add_on_purchase_relation)
      end

      context 'when duo_code_review_dap_internal_users feature flag is enabled' do
        it 'returns true' do
          expect(available).to be true
        end
      end

      context 'when duo_code_review_dap_internal_users feature flag is disabled' do
        before do
          stub_feature_flags(duo_code_review_dap_internal_users: false)
        end

        it 'returns false' do
          expect(available).to be false
        end
      end
    end

    shared_examples 'Duo Pro/Core behavior' do
      before do
        add_on_purchase_relation = instance_double(ActiveRecord::Relation, exists?: false)
        allow(::GitlabSubscriptions::AddOnPurchase)
          .to receive(:for_active_add_ons)
          .with([:duo_enterprise], user)
          .and_return(add_on_purchase_relation)
      end

      context 'when user does not have Duo Pro/Core add-on' do
        before do
          allow(user).to receive(:allowed_to_use?).with(:duo_agent_platform).and_return(false)
        end

        it 'returns false' do
          expect(available).to be_falsey
        end
      end

      context 'when user has Duo Pro/Core add-on' do
        before do
          allow(user).to receive(:allowed_to_use?).with(:duo_agent_platform).and_return(true)
        end

        it_behaves_like 'duo_foundational_flows_enabled check'

        context 'when StageCheck returns false' do
          before do
            allow(::Gitlab::Llm::StageCheck).to receive(:available?)
              .with(resource, :duo_workflow).and_return(false)

            case resource
            when Project
              resource.project_setting.update!(duo_foundational_flows_enabled: true)
            when Group
              resource.namespace_settings.update!(duo_foundational_flows_enabled: true)
            end
          end

          it 'returns false' do
            expect(available).to be_falsey
          end
        end

        context 'when StageCheck returns true' do
          before do
            allow(::Gitlab::Llm::StageCheck).to receive(:available?)
              .with(resource, :duo_workflow).and_return(true)

            case resource
            when Project
              resource.project_setting.update!(duo_foundational_flows_enabled: true)
            when Group
              resource.namespace_settings.update!(duo_foundational_flows_enabled: true)
            end
          end

          context 'on self-managed instances' do
            before do
              stub_saas_features(gitlab_com_subscriptions: false)
            end

            context 'with cloud-connected model (feature_setting is nil or not self_hosted)' do
              let(:feature_setting) { nil }
              let(:service_result) { ServiceResponse.success(payload: feature_setting) }

              before do
                allow(::Ai::FeatureSettingSelectionService).to receive(:new)
                  .with(user, :duo_agent_platform, resource.root_ancestor)
                  .and_return(instance_double(::Ai::FeatureSettingSelectionService, execute: service_result))
              end

              it 'returns true (DWS check not required for cloud-connected)' do
                expect(available).to be true
              end
            end

            context 'with self-hosted model' do
              let(:feature_setting) { instance_double(::Ai::FeatureSetting, self_hosted?: true) }
              let(:service_result) { ServiceResponse.success(payload: feature_setting) }

              before do
                allow(::Ai::FeatureSettingSelectionService).to receive(:new)
                  .with(user, :duo_agent_platform, resource.root_ancestor)
                  .and_return(instance_double(::Ai::FeatureSettingSelectionService, execute: service_result))
              end

              context 'when using supported model family' do
                let(:self_hosted_model) { create(:ai_self_hosted_model, model: :claude_3) }

                before do
                  allow(feature_setting).to receive(:self_hosted_model).and_return(self_hosted_model)
                end

                context 'when DWS URL is configured' do
                  before do
                    allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return('https://dws.example.com')
                  end

                  it 'returns true' do
                    expect(available).to be true
                  end
                end

                context 'when DWS URL is not configured' do
                  before do
                    allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(nil)
                  end

                  it 'returns false' do
                    expect(available).to be_falsey
                  end
                end
              end

              context 'when using unsupported model family' do
                let(:self_hosted_model) { create(:ai_self_hosted_model, model: :llama3) }

                before do
                  allow(feature_setting).to receive(:self_hosted_model).and_return(self_hosted_model)
                  allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return('https://dws.example.com')
                end

                it 'returns false even with DWS configured' do
                  expect(available).to be_falsey
                end
              end

              context 'when self_hosted_model is nil' do
                before do
                  allow(feature_setting).to receive(:self_hosted_model).and_return(nil)
                  allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return('https://dws.example.com')
                end

                it 'returns true when DWS is configured' do
                  expect(available).to be true
                end
              end
            end
          end

          context 'on SaaS', :saas do
            before do
              stub_saas_features(gitlab_com_subscriptions: true)
            end

            it 'returns true (DWS always available on SaaS)' do
              expect(available).to be true
            end
          end
        end
      end
    end

    context 'with Project resource' do
      let(:resource) { project }
      let(:validator) { described_class.new(user: user, resource: resource) }

      before do
        project.project_setting.update!(duo_features_enabled: true)
      end

      it_behaves_like 'duo features disabled check'
      it_behaves_like 'Duo Enterprise behavior'
      it_behaves_like 'Duo Pro/Core behavior'
    end

    context 'with Group resource' do
      let(:resource) { group }
      let(:validator) { described_class.new(user: user, resource: resource) }

      before do
        group.namespace_settings.update!(duo_features_enabled: true)
      end

      it_behaves_like 'duo features disabled check'
      it_behaves_like 'Duo Enterprise behavior'
      it_behaves_like 'Duo Pro/Core behavior'
    end
  end
end
