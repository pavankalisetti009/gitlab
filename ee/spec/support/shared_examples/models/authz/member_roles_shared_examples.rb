# frozen_string_literal: true

RSpec.shared_context 'with member roles assigned to group links' do
  let_it_be(:sre_group) { create(:group) }
  let_it_be(:developers_group) { create(:group) }

  let_it_be(:developer_lead) do
    create(:member_role, :instance, manage_merge_request_settings: true, read_code: false)
  end

  let_it_be(:platform_engineer) do
    create(:member_role, :instance, admin_cicd_variables: true, read_code: false)
  end

  let_it_be(:kate) { create(:group_member, :owner, source: sre_group) }
  let_it_be(:joe) { create(:group_member, :developer, source: sre_group, member_role: developer_lead) }
  let_it_be(:mark) { create(:group_member, :developer, source: sre_group, member_role: platform_engineer) }
  let_it_be(:jake) { create(:group_member, :developer, source: sre_group) }
  let_it_be(:mary) { create(:group_member, :guest, source: sre_group) }

  let_it_be(:sarah) { create(:group_member, :developer, source: developers_group, member_role: developer_lead) }
  let_it_be(:bob) { create(:group_member, :developer, source: developers_group) }
  let_it_be(:owen) { create(:group_member, :guest, source: developers_group) }

  before do
    create(
      :group_group_link,
      shared_group: group,
      shared_with_group: sre_group,
      member_role: platform_engineer
    )

    create(
      :group_group_link,
      shared_group: group,
      shared_with_group: developers_group
    )
  end
end

RSpec.shared_examples 'returns expected member role abilities' do
  using RSpec::Parameterized::TableSyntax

  where(:member, :expected_result) do
    ref(:kate)  | [:admin_cicd_variables]
    ref(:joe)   | [:manage_merge_request_settings]
    ref(:mark)  | [:admin_cicd_variables]
    ref(:jake)  | []
    ref(:mary)  | []
    ref(:sarah) | []
    ref(:bob)   | []
    ref(:owen)  | []
  end

  with_them do
    let(:user) { member.user }

    context 'when on SaaS', :saas do
      context 'when feature-flag `assign_custom_roles_to_group_links_saas` for group is enabled' do
        before do
          stub_feature_flags(assign_custom_roles_to_group_links_saas: [group])
        end

        it 'returns expected result' do
          expect(result[source.id]).to match_array(expected_result)
        end
      end

      context 'when feature-flag `assign_custom_roles_to_group_links_saas` for another group is enabled' do
        let(:another_group) { build(:group) }

        before do
          stub_feature_flags(assign_custom_roles_to_group_links_saas: [another_group])
        end

        it 'returns empty array' do
          expect(result[source.id]).to match_array([])
        end
      end

      context 'when feature-flag `assign_custom_roles_to_group_links_saas` is disabled' do
        before do
          stub_feature_flags(assign_custom_roles_to_group_links_saas: false)
        end

        it 'returns empty array' do
          expect(result[source.id]).to match_array([])
        end
      end
    end

    context 'when on self-managed' do
      context 'when feature-flag `assign_custom_roles_to_group_links_sm` is enabled' do
        it 'returns expected result' do
          expect(result[source.id]).to match_array(expected_result)
        end
      end

      context 'when feature-flag `assign_custom_roles_to_group_links_sm` is disabled' do
        before do
          stub_feature_flags(assign_custom_roles_to_group_links_sm: false)
        end

        it 'returns empty array' do
          expect(result[source.id]).to match_array([])
        end
      end
    end
  end
end
