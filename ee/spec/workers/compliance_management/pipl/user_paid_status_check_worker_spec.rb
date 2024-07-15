# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::UserPaidStatusCheckWorker,
  :saas, :use_clean_rails_redis_caching, feature_category: :compliance_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user) }

  let(:cache_key) { [ComplianceManagement::Pipl::PIPL_SUBJECT_USER_CACHE_KEY, user.id] }

  it_behaves_like 'an idempotent worker' do
    subject(:worker) { described_class.new }

    where(:user_is_paid, :subject_to_pipl) do
      true  | false
      false | true
    end

    with_them do
      it "caches the user's subject to PIPL status for 24 hours", :aggregate_failures do
        if user_is_paid
          create(:group_with_plan, plan: :ultimate_plan, developers: user)
        else
          create(:group_with_plan, plan: :free_plan, developers: user)
        end

        expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 24.hours).and_call_original

        assert_subject_to_pipl?(subject_to_pipl)
      end
    end

    context 'when user belongs to a paid namespace as a guest' do
      context 'when namespace plan excludes guests from billable users' do
        it 'treats the user as paid' do
          create(:group_with_plan, plan: :ultimate_plan, guests: user)

          assert_subject_to_pipl?(false)
        end
      end

      context 'when namespace plan treats guests as billable users' do
        it 'treats the user as paid' do
          create(:group_with_plan, plan: :premium_plan, guests: user)

          assert_subject_to_pipl?(false)
        end
      end
    end

    context 'when user belongs to a paid namespace with minimal access' do
      it 'treats the user as paid' do
        stub_licensed_features(minimal_access_role: true)

        group = create(:group_with_plan, plan: :ultimate_plan)
        create(:group_member, :minimal_access, source: group, user: user)

        assert_subject_to_pipl?(false)
      end
    end

    context 'when user cannot be found' do
      it 'does not do anything' do
        expect(Rails.cache).not_to receive(:fetch)

        worker.perform(non_existing_record_id)
      end
    end
  end

  def assert_subject_to_pipl?(subject_to_pipl)
    expect { worker.perform(user.id) }.to change { Rails.cache.read(cache_key) }.from(nil).to(subject_to_pipl)
  end
end
