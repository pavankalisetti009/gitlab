# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting squash options for a branch protection', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:maintainer_user) { create(:user, maintainer_of: project) }
  let_it_be(:guest_user) { create(:user, guest_of: project) }
  let_it_be(:variables) { { path: project.full_path } }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }
  let_it_be(:squash_option) { create(:branch_rule_squash_option, protected_branch: protected_branch, project: project) }

  let(:fields) { all_graphql_fields_for('SquashOption') }

  let(:query) do
    <<~GQL
    query($path: ID!) {
      project(fullPath: $path) {
        branchRules {
          nodes{
            squashOption {
              #{fields}
            }
          }
        }
      }
    }
    GQL
  end

  let(:branch_rules_data) do
    graphql_data_at(:project, :branch_rules, :nodes)
  end

  before do
    stub_licensed_features(branch_rule_squash_options: true)
  end

  context 'when user is not authorized' do
    let(:current_user) { guest_user }

    before do
      post_graphql(query, current_user: current_user, variables: variables)
    end

    it_behaves_like 'a working graphql query'

    it { expect(branch_rules_data).to be_empty }
  end

  context 'when user is authorized' do
    let(:current_user) { maintainer_user }

    context 'and the feature is not available' do
      before do
        stub_licensed_features(branch_rule_squash_options: false)
      end

      it 'returns nil for squashOption' do
        post_graphql(query, current_user: current_user, variables: variables)

        expect(branch_rules_data.dig(0, 'squashOption')).to be_nil
      end
    end

    context 'and the branch_rule_squash_settings flag is enabled' do
      before do
        post_graphql(query, current_user: current_user, variables: variables)
      end

      it_behaves_like 'a working graphql query'

      it 'returns squash option attributes' do
        expect(branch_rules_data.size).to eq(1)

        attributes = branch_rules_data.dig(0, 'squashOption')
        expect(attributes['option']).to eq('Allow')
        expect(attributes['helpText']).to eq('Squashing is always performed. Checkbox is visible and ' \
          'selected, and users cannot change it.')
      end
    end

    context 'when the branch_rule_squash_settings flag is not enabled' do
      before do
        stub_feature_flags(branch_rule_squash_settings: false)
        post_graphql(query, current_user: current_user, variables: variables)
      end

      it 'returns nil for squashOption' do
        expect(branch_rules_data.dig(0, 'squashOption')).to be_nil
      end
    end
  end
end
