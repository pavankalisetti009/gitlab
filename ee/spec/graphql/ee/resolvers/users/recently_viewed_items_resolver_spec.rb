# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Users::RecentlyViewedItemsResolver, feature_category: :notifications do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:user) { create(:user) }

    it 'includes recent epics' do
      expect(Gitlab::Search::RecentEpics).to receive(:new).with(user: user).and_call_original
      resolve_recent_items(current_user: user)
    end
  end

  def resolve_recent_items(current_user:)
    resolve(described_class, obj: current_user, ctx: { current_user: current_user })
  end
end
