# frozen_string_literal: true

RSpec.shared_examples 'read_duo_usage_analytics permissions' do
  using RSpec::Parameterized::TableSyntax

  where(:role, :ai_analytics_licensed, :feature_flag_enabled, :allowed) do
    :guest    | false | false | false
    :guest    | false | true | false
    :guest    | true  | false | false
    :guest    | true  | true | false
    :reporter | false | false | false
    :reporter | false | true | false
    :reporter | true | false | false
    :reporter | true | true | true
  end

  with_them do
    let(:current_user) { public_send(role) }

    before do
      stub_feature_flags(duo_usage_dashboard: feature_flag_enabled)
      stub_licensed_features(ai_analytics: ai_analytics_licensed)
    end

    it { is_expected.to(allowed ? be_allowed(:read_duo_usage_analytics) : be_disallowed(:read_duo_usage_analytics)) }
  end
end
