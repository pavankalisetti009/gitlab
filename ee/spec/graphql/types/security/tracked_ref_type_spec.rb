# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::TrackedRefType, feature_category: :vulnerability_management do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  before_all { project.add_developer(user) }

  specify { expect(described_class).to require_graphql_authorizations(:read_security_project_tracked_refs) }

  describe 'custom field resolvers' do
    let(:tracked_ref) { create(:security_project_tracked_context, :tracked, project: project) }
    let(:type_instance) { described_class.send(:new, tracked_ref, {}) }

    describe '#state' do
      where(:tracked_status, :expected_state) do
        true  | 'TRACKED'
        false | 'UNTRACKED'
      end

      with_them do
        it "returns #{params[:expected_state]} when tracked? is #{params[:tracked_status]}" do
          allow(tracked_ref).to receive(:tracked?).and_return(tracked_status)
          expect(type_instance.state).to eq(expected_state)
        end
      end
    end
  end
end
