# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Projects::ParticipantsService, feature_category: :code_review_workflow do
  describe '#execute' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:service_account_user) { create(:user, :service_account) }
    let_it_be(:agent) { create(:user, :service_account) }
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    subject do
      described_class.new(project, current_user, {}).execute(merge_request)
    end

    before_all do
      agent.update!(composite_identity_enforced: true)
    end

    context 'when project does not have access to Duo Code review' do
      before do
        allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(false)
      end

      it { is_expected.not_to include(a_hash_including({ username: ::Users::Internal.duo_code_review_bot.username })) }
    end

    context 'when project has access Duo Code review' do
      before do
        allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(true)
      end

      it { is_expected.to include(a_hash_including({ username: ::Users::Internal.duo_code_review_bot.username })) }
    end

    describe 'disabled fields' do
      context 'when regular user' do
        it { is_expected.to include(a_hash_including({ disabled: false, disabled_reason: "" })) }
      end

      context 'when service account user' do
        context 'when non agent' do
          let(:current_user) { service_account_user }

          before_all do
            project.add_developer(service_account_user)
          end

          it 'is not disabled' do
            is_expected.to include(a_hash_including({ username: service_account_user.username, disabled: false,
           disabled_reason: "" }))
          end
        end

        context 'when agent' do
          let(:current_user) { agent }

          before_all do
            project.add_developer(agent)
          end

          context 'when credits are available' do
            before do
              allow_next_instance_of(::Ai::UsageQuotaService) do |instance|
                allow(instance).to receive(:execute).and_return(ServiceResponse.success)
              end
            end

            it 'is not disabled' do
              is_expected.to include(a_hash_including({ username: agent.username, disabled: false,
disabled_reason: "" }))
            end
          end

          context 'when credits are expired' do
            before do
              allow_next_instance_of(::Ai::UsageQuotaService) do |instance|
                allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: "no credits"))
              end
            end

            it 'is disabled' do
              is_expected.to include(a_hash_including({ username: agent.username, disabled: true,
             disabled_reason: "Unavailable - no credits" }))
            end
          end
        end
      end
    end
  end
end
