# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Namespaces, :aggregate_failures, :api, feature_category: :subscription_management do
  include AfterNextHelpers

  def namespace_path(namespace_id)
    "/internal/gitlab_subscriptions/namespaces/#{namespace_id}"
  end

  describe 'GET /internal/gitlab_subscriptions/namespaces/:id' do
    let_it_be(:admin) { create(:admin) }
    let_it_be(:namespace) { create(:group) }

    context 'when unauthenticated' do
      it 'returns an error response' do
        get api(namespace_path(namespace.id))

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when the user is not an admin' do
      it 'returns an error response' do
        user = create(:user)

        get api(namespace_path(namespace.id), user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the admin is not in admin mode' do
      it 'returns an error response' do
        get api(namespace_path(namespace.id), admin, admin_mode: false)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the namespace cannot be found' do
      it 'returns an error response' do
        get api(namespace_path('0'), admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the namespace is of a group' do
      it 'returns OK status and contains some set of keys' do
        get api(namespace_path(namespace.id), admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to contain_exactly('id', 'kind', 'name', 'path', 'full_path',
          'parent_id', 'members_count_with_descendants',
          'plan', 'shared_runners_minutes_limit',
          'avatar_url', 'web_url', 'trial_ends_on', 'trial',
          'extra_shared_runners_minutes_limit', 'billable_members_count',
          'root_repository_size', 'projects_count',
          'additional_purchased_storage_size', 'additional_purchased_storage_ends_on')
      end
    end

    context 'when the namespace is of a user' do
      let_it_be(:user) { create(:user, :with_namespace) }
      let_it_be(:namespace) { user.namespace }

      it 'returns OK status and contains some set of keys' do
        get api(namespace_path(namespace.id), admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to contain_exactly('id', 'kind', 'name', 'path', 'full_path',
          'parent_id', 'plan', 'shared_runners_minutes_limit',
          'avatar_url', 'web_url', 'trial_ends_on', 'trial',
          'extra_shared_runners_minutes_limit', 'billable_members_count',
          'additional_purchased_storage_size', 'additional_purchased_storage_ends_on')
      end
    end
  end

  describe 'PUT /internal/gitlab_subscriptions/namespaces/:id' do
    let(:admin) { create(:admin) }
    let(:user) { create(:user) }

    let(:group1) { create(:group, :with_ci_minutes, ci_minutes_used: 1600) }
    let_it_be(:group2) { create(:group, :nested) }
    let_it_be(:ultimate_plan) { create(:ultimate_plan) }
    let_it_be(:project) { create(:project, namespace: group2, name: group2.name, path: group2.path) }
    let_it_be(:project_namespace) { project.project_namespace }

    let(:usage) do
      ::Ci::Minutes::NamespaceMonthlyUsage.current_month.find_by(namespace_id: group1)
    end

    let(:params) do
      {
        shared_runners_minutes_limit: 9001,
        additional_purchased_storage_size: 10_000,
        additional_purchased_storage_ends_on: Date.today.to_s
      }
    end

    before do
      usage.update!(notification_level: 30)
      group1.update!(shared_runners_minutes_limit: 1000, extra_shared_runners_minutes_limit: 500)
    end

    context 'when unauthenticated' do
      it 'returns an error response' do
        put api(namespace_path(group1.id))

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when the user is not an admin' do
      it 'returns an error response' do
        user = create(:user)

        put api(namespace_path(group1.id), user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the admin is not in admin mode' do
      it 'returns an error response' do
        put api(namespace_path(group1.id), admin, admin_mode: false)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the namespace cannot be found' do
      it 'returns an error response' do
        put api(namespace_path('0'), admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when authenticated as admin' do
      subject(:request) { put api(namespace_path(group1.id), admin, admin_mode: true), params: params }

      let(:group1) { create(:group, :with_ci_minutes, ci_minutes_used: 1600, name: 'Hello.World') }

      it 'updates namespace using full_path when full_path contains dots' do
        put api(namespace_path(group1.full_path), admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['shared_runners_minutes_limit']).to eq(params[:shared_runners_minutes_limit])
        expect(json_response['additional_purchased_storage_size']).to eq(params[:additional_purchased_storage_size])
        expect(
          json_response['additional_purchased_storage_ends_on']
        ).to eq(params[:additional_purchased_storage_ends_on])
      end

      it 'updates namespace using id' do
        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['shared_runners_minutes_limit']).to eq(params[:shared_runners_minutes_limit])
        expect(json_response['additional_purchased_storage_size']).to eq(params[:additional_purchased_storage_size])
        expect(
          json_response['additional_purchased_storage_ends_on']
        ).to eq(params[:additional_purchased_storage_ends_on])
      end

      it 'expires the compute minutes CachedQuota' do
        expect_next(Gitlab::Ci::Minutes::CachedQuota).to receive(:expire!)

        request
      end

      context 'when current compute minutes notification level is set' do
        it 'resets the current compute minutes notification level' do
          expect do
            request
          end.to change { usage.reload.notification_level }
             .to(Ci::Minutes::Notification::PERCENTAGES.fetch(:not_set))
        end
      end

      shared_examples 'handles monthly usage' do
        it 'expires the compute minutes CachedQuota' do
          expect_next(Gitlab::Ci::Minutes::CachedQuota).to receive(:expire!)

          request
        end

        it 'resets the current compute minutes notification level' do
          expect do
            request
          end.to change { usage.reload.notification_level }
            .to(Ci::Minutes::Notification::PERCENTAGES.fetch(:not_set))
        end
      end

      context 'when request has extra_shared_runners_minutes_limit param' do
        before do
          params[:extra_shared_runners_minutes_limit] = 1000
          params.delete(:shared_runners_minutes_limit)
        end

        it 'updates the extra shared runners minutes limit' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['extra_shared_runners_minutes_limit'])
            .to eq(params[:extra_shared_runners_minutes_limit])
        end

        it 'updates pending builds data since adding extra minutes the quota is not used up anymore' do
          minutes_exceeded = group1.ci_minutes_usage.minutes_used_up?
          expect(minutes_exceeded).to eq(true)

          pending_build = create(:ci_pending_build, namespace: group1, minutes_exceeded: minutes_exceeded)

          request

          expect(pending_build.reload.minutes_exceeded).to eq(false)
        end

        it_behaves_like 'handles monthly usage'
      end

      context 'when shared_runners_minutes_limit param is present' do
        before do
          params[:shared_runners_minutes_limit] = nil
        end

        it_behaves_like 'handles monthly usage'
      end

      context 'when neither minutes limit params is provided' do
        it 'does not expire the compute minutes CachedQuota' do
          params.delete(:shared_runners_minutes_limit)
          expect(Gitlab::Ci::Minutes::CachedQuota).not_to receive(:new)

          request
        end

        context 'when current compute minutes notification level is set' do
          it 'does not reset the current compute minutes notification level' do
            params.delete(:shared_runners_minutes_limit)

            expect do
              put api(namespace_path(group1.id), admin), params: params
            end.not_to change { usage.reload.notification_level }
          end
        end
      end
    end

    context 'when project namespace is passed' do
      it 'returns 404' do
        put api(namespace_path(project_namespace.id), admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response).to eq('message' => '404 Namespace Not Found')
      end
    end

    context 'when invalid params' do
      where(:attr) do
        [
          :shared_runners_minutes_limit,
          :additional_purchased_storage_size,
          :additional_purchased_storage_ends_on
        ]
      end

      with_them do
        it "returns validation error for #{attr}" do
          put api(namespace_path(group1.id), admin, admin_mode: true), params: Hash[attr, 'unknown']

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    [:last_ci_minutes_notification_at, :last_ci_minutes_usage_notification_level].each do |attr|
      context "when namespace has a value for #{attr}" do
        before do
          group1.update_attribute(attr, Time.now)
        end

        it 'resets that value when assigning extra compute minutes' do
          expect do
            put api(namespace_path(group1.full_path), admin, admin_mode: true),
              params: { extra_shared_runners_minutes_limit: 1000 }
          end.to change { group1.reload.send(attr) }.to(nil)
        end
      end
    end

    context "when customer purchases extra compute minutes" do
      it "ticks instance runners" do
        runners = Ci::Runner.instance_type

        put api(namespace_path(group1.id), admin), params: { extra_shared_runners_minutes_limit: 1000 }

        expect(runners).to all(receive(:tick_runner_queue))
      end
    end

    context "when passing attributes for gitlab_subscription", :saas do
      let(:gitlab_subscription) do
        {
          start_date: '2019-06-01',
          end_date: '2020-06-01',
          plan_code: 'ultimate',
          seats: 20,
          max_seats_used: 10,
          auto_renew: true,
          trial: true,
          trial_ends_on: '2019-05-01',
          trial_starts_on: '2019-06-01',
          trial_extension_type: GitlabSubscription.trial_extension_types[:reactivated]
        }
      end

      it "creates the gitlab_subscription record" do
        expect(group1.gitlab_subscription).to be_nil

        put api(namespace_path(group1.id), admin, admin_mode: true), params: {
          gitlab_subscription_attributes: gitlab_subscription
        }

        expect(group1.reload.gitlab_subscription).to have_attributes(
          start_date: Date.parse(gitlab_subscription[:start_date]),
          end_date: Date.parse(gitlab_subscription[:end_date]),
          hosted_plan: instance_of(Plan),
          seats: 20,
          max_seats_used: 10,
          auto_renew: true,
          trial: true,
          trial_starts_on: Date.parse(gitlab_subscription[:trial_starts_on]),
          trial_ends_on: Date.parse(gitlab_subscription[:trial_ends_on]),
          trial_extension_type: 'reactivated'
        )
      end

      it "updates the gitlab_subscription record" do
        existing_subscription = group1.create_gitlab_subscription!

        put api(namespace_path(group1.id), admin, admin_mode: true), params: {
          gitlab_subscription_attributes: gitlab_subscription
        }

        expect(group1.reload.gitlab_subscription.reload.seats).to eq 20
        expect(group1.gitlab_subscription).to eq existing_subscription
      end

      context 'when params are invalid' do
        it 'returns a 400 error' do
          put api(namespace_path(group1.id), admin, admin_mode: true), params: {
            gitlab_subscription_attributes: { start_date: nil, seats: nil }
          }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq(
            "gitlab_subscription.seats" => ["can't be blank"],
            "gitlab_subscription.start_date" => ["can't be blank"]
          )
        end
      end
    end
  end
end
