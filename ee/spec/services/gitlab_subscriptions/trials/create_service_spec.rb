# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::CreateService, feature_category: :plan_provisioning do
  include TrialHelpers

  let_it_be(:user, reload: true) { create(:user) }
  let_it_be(:organization) { create(:organization, users: [user]) }
  let(:step) { described_class::LEAD }

  describe '#execute', :saas, :use_clean_rails_memory_store_caching do
    let(:trial_params) { {} }
    let(:extra_lead_params) { {} }
    let(:trial_user_params) do
      { trial_user: lead_params(user, extra_lead_params) }
    end

    let(:lead_service_class) { GitlabSubscriptions::CreateLeadService }
    let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyTrialService }
    let(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }

    subject(:execute) do
      described_class.new(
        step: step, lead_params: lead_params(user, extra_lead_params), trial_params: trial_params, user: user
      ).execute
    end

    context 'when on the lead step' do
      it_behaves_like 'successful lead creation for one eligible namespace', :free_plan do
        before do
          Rails.cache.write("namespaces:eligible_trials:#{group.id}", GitlabSubscriptions::Trials::TRIAL_TYPES)
        end
      end

      it_behaves_like 'successful lead creation for no eligible namespaces'
      it_behaves_like 'successful lead creation for multiple eligible namespaces', :free_plan do
        before do
          Rails.cache.write("namespaces:eligible_trials:#{group.id}", GitlabSubscriptions::Trials::TRIAL_TYPES)
          Rails.cache.write("namespaces:eligible_trials:#{another_group.id}", GitlabSubscriptions::Trials::TRIAL_TYPES)
        end
      end

      it_behaves_like 'lead creation fails'
    end

    it_behaves_like 'unknown step for trials'
    it_behaves_like 'no step for trials'

    context 'when on trial step' do
      let(:step) { described_class::TRIAL }

      it_behaves_like 'trial step existing namespace flow', :free_plan do
        before do
          Rails.cache.write("namespaces:eligible_trials:#{group.id}", GitlabSubscriptions::Trials::TRIAL_TYPES)
        end
      end

      it_behaves_like 'trial step existing namespace flow', :premium_plan do
        before do
          Rails.cache.write("namespaces:eligible_trials:#{group.id}", GitlabSubscriptions::Trials::TRIAL_TYPES)
        end
      end

      it_behaves_like 'trial step error conditions'
    end

    it_behaves_like 'for tracking the lead step', :free_plan, '' do
      before do
        Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", GitlabSubscriptions::Trials::TRIAL_TYPES)
      end
    end

    it_behaves_like 'for tracking the trial step', :free_plan, '' do
      before do
        Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", GitlabSubscriptions::Trials::TRIAL_TYPES)
      end
    end

    context 'with an ineligible namespace' do
      let_it_be(:group) { create(:group, owners: user) }
      let(:step) { described_class::TRIAL }
      let(:namespace_id) { group.id.to_s }
      let(:trial_params) { { namespace_id: namespace_id } }

      before do
        Rails.cache.write("namespaces:eligible_trials:#{namespace_id}", ['gitlab_duo_pro'])
      end

      it 'returns an error' do
        expect(apply_trial_service_class).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.reason).to eq(:not_found)
      end
    end

    context 'when in the create group flow' do
      let(:step) { described_class::TRIAL }
      let(:extra_params) { { organization_id: organization.id, with_add_on: true, add_on_name: "duo_enterprise" } }

      let(:trial_params) do
        { new_group_name: 'gitlab', namespace_id: '0' }.merge(extra_params)
      end

      context 'when group is successfully created' do
        context 'when trial creation is successful' do
          it 'return success with the namespace' do
            allow(::Namespace.sticking).to receive(:stick).with(anything, anything).and_call_original

            expect_next_instance_of(apply_trial_service_class) do |instance|
              expect(instance).to receive(:execute).and_return(
                ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
              )
            end

            expect { execute }.to change { Group.count }.by(1)

            expect(::Namespace.sticking).to have_received(:stick).with(:namespace, Group.last.id)
            expect(execute).to be_success
            expect(execute.payload).to eq({ namespace: Group.last, add_on_purchase: add_on_purchase })
          end
        end

        context 'when trial creation fails' do
          it 'returns an error indicating trial failed' do
            stub_apply_trial(
              user, namespace_id: anything, success: false, extra_params: extra_params.merge(new_group_attrs)
            )

            expect { execute }.to change { Group.count }.by(1)

            expect(execute).to be_error
            expect(execute.payload).to eq({ namespace_id: Group.last.id })
          end
        end

        context 'when group name needs sanitized' do
          it 'return success with the namespace path sanitized for duplication' do
            create(:group_with_plan, plan: :free_plan, name: 'gitlab')

            stub_apply_trial(
              user, namespace_id: anything, success: true,
              extra_params: extra_params.merge(new_group_attrs(path: 'gitlab1'))
            )

            expect { execute }.to change { Group.count }.by(1)

            expect(execute).to be_success
            expect(execute.payload[:namespace].path).to eq('gitlab1')
          end
        end
      end

      context 'when user is not allowed to create groups' do
        before do
          user.can_create_group = false
        end

        it 'returns not_found' do
          expect(apply_trial_service_class).not_to receive(:new)

          expect { execute }.not_to change { Group.count }
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when group creation had an error' do
        context 'when there are invalid characters used' do
          let(:trial_params) { { new_group_name: ' _invalid_ ', namespace_id: '0', organization_id: organization.id } }

          it 'returns namespace_create_failed' do
            expect(apply_trial_service_class).not_to receive(:new)

            expect { execute }.not_to change { Group.count }
            expect(execute).to be_error
            expect(execute.reason).to eq(:namespace_create_failed)
            expect(execute.message.to_sentence).to match(/^Group URL can only include non-accented letters/)
            expect(execute.payload[:namespace_id]).to eq('0')
          end
        end

        context 'when name is entered with blank spaces' do
          let(:trial_params) { { new_group_name: '  ', namespace_id: '0', organization_id: organization.id } }

          it 'returns namespace_create_failed' do
            expect(apply_trial_service_class).not_to receive(:new)

            expect { execute }.not_to change { Group.count }
            expect(execute).to be_error
            expect(execute.reason).to eq(:namespace_create_failed)
            expect(execute.message.to_sentence).to match(/^Name can't be blank/)
            expect(execute.payload[:namespace_id]).to eq('0')
          end
        end
      end
    end

    context 'when lead was submitted with an intended namespace' do
      let(:trial_params) { { namespace_id: non_existing_record_id.to_s } }

      it 'does not create a trial and returns that there is no namespace' do
        stub_lead_without_trial(trial_user_params)

        expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
      end
    end
  end

  def lead_params(user, extra_lead_params)
    {
      company_name: 'GitLab',
      first_name: user.first_name,
      last_name: user.last_name,
      phone_number: '+1 23 456-78-90',
      country: 'US',
      work_email: user.email,
      uid: user.id,
      setup_for_company: user.onboarding_status_setup_for_company,
      skip_email_confirmation: true,
      gitlab_com_trial: true,
      provider: 'gitlab',
      state: 'CA'
    }.merge(extra_lead_params)
  end
end
