# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Members::StandardRolesResolver, feature_category: :api do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:result) do
      resolve(described_class, obj: group, lookahead: positive_lookahead, arg_style: :internal)
    end

    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user) }

    context 'when a user has maintainer access' do
      before do
        group.add_member(user, ::Gitlab::Access::MAINTAINER)
      end

      it 'returns the totals for each standard role' do
        expect(result).to be_present
        expect(result.count).to eq(6)

        ::Gitlab::Access.options_with_minimal_access.sort_by { |_, v| v }.each_with_index do |(name, value), index|
          role = result[index]
          expect(role[:access_level]).to eq(value)
          expect(role[:name]).to eq(name)
          expect(role[:members_count]).to eq(value == ::Gitlab::Access::MAINTAINER ? 1 : 0)
          expect(role[:users_count]).to eq(value == ::Gitlab::Access::MAINTAINER ? 1 : 0)
          expect(role[:group]).to eq(group)
        end
      end
    end
  end
end
