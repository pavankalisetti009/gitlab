# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'graphql queries', feature_category: :api do
  describe 'complexity' do
    Gitlab::Graphql::Queries.all.each do |definition| # rubocop:disable Rails/FindEach -- Not an ActiveRecord relation
      describe definition.file do
        it 'does not exceed complexity limit' do
          expect(definition.complexity(GitlabSchema)).to be < GitlabSchema::AUTHENTICATED_MAX_COMPLEXITY
        end
      end
    end
  end
end
