# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::TargetedMessagesHelper, feature_category: :acquisition do
  describe '#targeted_message_id_for' do
    using RSpec::Parameterized::TableSyntax

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted objects
    let_it_be(:group) { create(:group) }
    let_it_be(:targeted_group) { create(:targeted_message_namespace, namespace: group) }
    let_it_be(:user) { create(:user) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    let(:targeted_message_id) { targeted_group.targeted_message_id }

    subject { helper.targeted_message_id_for(group) }

    where(:saas, :feature_flag_enabled, :is_owner, :expected_result) do
      true  | true  | true  | ref(:targeted_message_id)
      false | true  | true  | nil
      true  | false | true  | nil
      true  | true  | false | nil
    end

    with_them do
      before do
        stub_saas_features(targeted_messages: saas)
        stub_feature_flags(targeted_messages_admin_ui: feature_flag_enabled)

        group.add_owner(user) if is_owner # rubocop:disable RSpec/BeforeAllRoleAssignment -- Does not work in before_all
        allow(helper).to receive(:current_user).and_return(user)
      end

      it { is_expected.to be(expected_result) }
    end
  end
end
