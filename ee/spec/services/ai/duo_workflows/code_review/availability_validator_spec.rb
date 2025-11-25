# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::AvailabilityValidator, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  let(:validator) { described_class.new(user: user, merge_request: merge_request) }

  describe '#available?' do
    subject(:available) { validator.available? }

    context 'when user cannot create notes on the merge request' do
      let(:guest_user) { create(:user, guest_of: project) }
      let(:validator) { described_class.new(user: guest_user, merge_request: merge_request) }

      before do
        project.project_setting.update!(duo_features_enabled: true)
      end

      it 'returns false' do
        expect(available).to be false
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(duo_code_review_on_agent_platform: false)
      end

      it 'returns false' do
        expect(available).to be false
      end
    end

    context 'when feature flag is enabled' do
      before do
        project.project_setting.update!(duo_features_enabled: true)
      end

      context 'when project does not have duo_features_enabled' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
        end

        it 'returns false' do
          expect(available).to be false
        end
      end

      context 'with Duo Enterprise' do
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

      context 'with Duo Pro/Core' do
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

          context 'on self-managed instances' do
            before do
              stub_saas_features(gitlab_com_subscriptions: false)
              stub_ee_application_setting(instance_level_ai_beta_features_enabled: beta_enabled)
            end

            context 'when instance beta features are disabled' do
              let(:beta_enabled) { false }

              it 'returns false' do
                expect(available).to be_falsey
              end
            end

            context 'when instance beta features are enabled' do
              let(:beta_enabled) { true }
              let(:feature_setting) { instance_double(::Ai::FeatureSetting, self_hosted?: true) }

              before do
                allow(::Ai::FeatureSetting).to receive(:find_by_feature)
                  .with('review_merge_request')
                  .and_return(feature_setting)
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

            context 'when experiment features are disabled' do
              before do
                allow(project.root_ancestor).to receive(:experiment_features_enabled).and_return(false)
              end

              it 'returns false' do
                expect(available).to be_falsey
              end
            end

            context 'when experiment features are enabled' do
              before do
                allow(project.root_ancestor).to receive(:experiment_features_enabled).and_return(true)
              end

              it 'returns true' do
                expect(available).to be true
              end
            end
          end
        end
      end
    end
  end
end
