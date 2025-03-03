# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CiDedicatedHostedRunnerFilters'], feature_category: :hosted_runners do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:runner1) { create(:ci_runner) }
  let_it_be(:runner2) { create(:ci_runner) }
  let_it_be(:usage1) { create(:ci_hosted_runner_monthly_usage, runner: runner1, billing_month: Date.new(2023, 1, 1)) }
  let_it_be(:usage2) { create(:ci_hosted_runner_monthly_usage, runner: runner2, billing_month: Date.new(2024, 1, 1)) }

  let(:filters) { graphql_response.dig('data', 'ciDedicatedHostedRunnerFilters') }
  let(:query) do
    %(
      query {
        ciDedicatedHostedRunnerFilters {
          #{query_field}
        }
      }
    )
  end

  let_it_be(:fields) { %i[runners years] }

  subject(:graphql_response) { GitlabSchema.execute(query, context: { current_user: admin }).as_json }

  before do
    stub_application_setting(gitlab_dedicated_instance: true)
  end

  it { expect(described_class).to have_graphql_fields(fields) }

  describe 'fields' do
    let(:type_fields) { described_class.fields }

    it { expect(type_fields['runners'].type).to be_present }
    it { expect(type_fields['years'].type).to be_present }
    it { expect(type_fields['years'].type.to_type_signature).to eq('[Int!]') }
  end

  describe 'runners field' do
    let(:query_field) { 'runners { nodes { id } }' }

    context 'when user is not authorized' do
      let(:unauthorized_user) { create(:user) }

      subject(:graphql_response) { GitlabSchema.execute(query, context: { current_user: unauthorized_user }).as_json }

      it 'returns nil' do
        expect(filters['runners']).to be_nil
      end
    end

    context 'when user is authorized', :enable_admin_mode do
      it 'returns distinct runners' do
        runner_ids = filters.dig('runners', 'nodes').pluck('id')
        expect(runner_ids).to contain_exactly(
          runner1.to_global_id.to_s,
          runner2.to_global_id.to_s
        )
      end
    end
  end

  describe 'years field' do
    let(:query_field) { 'years' }

    context 'when user is not authorized' do
      let(:unauthorized_user) { create(:user) }

      subject(:graphql_response) { GitlabSchema.execute(query, context: { current_user: unauthorized_user }).as_json }

      it 'returns nil' do
        expect(filters['years']).to be_nil
      end
    end

    context 'when user is authorized', :enable_admin_mode do
      it 'returns all distinct years' do
        expect(filters['years']).to contain_exactly(2023, 2024)
      end
    end
  end
end
