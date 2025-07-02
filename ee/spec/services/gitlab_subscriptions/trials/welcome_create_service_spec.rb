# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::WelcomeCreateService, :saas, feature_category: :acquisition do
  include TrialHelpers

  let_it_be(:user, reload: true) { create(:user) }
  let_it_be(:organization) { create(:organization, users: [user]) }
  let_it_be(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }

  let(:glm_params) { { glm_source: 'some-source', glm_content: 'some-content' } }
  let(:group) { build(:group) }

  let(:params) do
    {
      first_name: 'John',
      last_name: 'Doe',
      company_name: 'Test Company',
      country: 'US',
      state: 'CA',
      project_name: 'Test Project',
      group_name: 'gitlab',
      organization_id: organization.id
    }.merge(glm_params)
  end

  let(:lead_params) do
    {
      trial_user: params.except(:namespace_id, :group_name, :project_name, :organization_id).merge(
        {
          work_email: user.email,
          uid: user.id,
          setup_for_company: false,
          skip_email_confirmation: true,
          gitlab_com_trial: true,
          provider: 'gitlab'
        }
      )
    }
  end

  let(:execute_params) { {} }

  let(:lead_service_class) { GitlabSubscriptions::CreateLeadService }
  let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyTrialService }

  subject(:execute) { described_class.new(params: params, user: user).execute(**execute_params) }

  describe '#execute' do
    context 'when successful' do
      it 'creates lead and applies trial successfully', :aggregate_failures do
        expect_create_lead_success(lead_params)
        expect_apply_trial_success(user, group, extra_params: glm_params.merge(
          namespace_id: be_a(Integer),
          namespace: {
            id: be_a(Integer),
            name: be_a(String),
            path: be_a(String),
            kind: group.kind,
            trial_ends_on: group.trial_ends_on,
            plan: be_a(String)
          }
        ))

        expect { execute }.to change { Group.count }.by(1).and change { Project.count }.by(1)
        is_expected.to be_success.and have_attributes(
          message: 'Trial applied',
          payload: {
            namespace_id: Group.last.id,
            add_on_purchase: add_on_purchase
          }
        )
      end
    end
  end
end
