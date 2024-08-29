# frozen_string_literal: true

RSpec.shared_examples 'permission to :read_ai_analytics' do
  using RSpec::Parameterized::TableSyntax

  where(:role, :flag_enabled, :has_duo_enterprise, :allowed) do
    :guest    | false | false | false
    :guest    | false | true  | false
    :guest    | true  | false | false
    :guest    | true  | true  | false
    :reporter | false | false | true
    :reporter | false | true  | true
    :reporter | true  | false | false
    :reporter | true  | true  | true
  end

  with_them do
    let(:current_user) { public_send(role) }

    before do
      stub_feature_flags(ai_impact_only_on_duo_enterprise: flag_enabled)

      if has_duo_enterprise
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: current_user,
          add_on_purchase: subscription_purchase
        )
      end
    end

    it { is_expected.to(allowed ? be_allowed(:read_ai_analytics) : be_disallowed(:read_ai_analytics)) }
  end
end
