# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Users::RecentlyViewedItemsResolver, feature_category: :notifications do
  include GraphqlHelpers

  describe '#resolve with EE features' do
    let_it_be(:user) { create(:user) }
    let_it_be(:epic) { create(:epic) }
    let_it_be(:issue) { create(:issue) }
    let_it_be(:merge_request) { create(:merge_request) }

    let(:epic_service) { instance_double(Gitlab::Search::RecentEpics) }
    let(:issue_service) { instance_double(Gitlab::Search::RecentIssues) }
    let(:mr_service) { instance_double(Gitlab::Search::RecentMergeRequests) }

    before do
      allow(Gitlab::Search::RecentEpics).to receive(:new).with(user: user).and_return(epic_service)
      allow(Gitlab::Search::RecentIssues).to receive(:new).with(user: user).and_return(issue_service)
      allow(Gitlab::Search::RecentMergeRequests).to receive(:new).with(user: user).and_return(mr_service)

      allow(Ability).to receive(:allowed?).with(user, :read_epic, anything).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_issue, anything).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_merge_request, anything).and_return(true)

      allow(epic_service).to receive(:latest_with_timestamps).and_return({})
      allow(issue_service).to receive(:latest_with_timestamps).and_return({})
      allow(mr_service).to receive(:latest_with_timestamps).and_return({})
    end

    it 'includes recent epics service' do
      expect(Gitlab::Search::RecentEpics).to receive(:new).with(user: user).and_return(epic_service)
      resolve_recent_items(current_user: user)
    end

    it 'filters out epics the user cannot read (SAML authorization failure)' do
      allow(epic_service).to receive(:latest_with_timestamps).and_return({
        epic => 1.hour.ago
      })

      allow(Ability).to receive(:allowed?).with(user, :read_epic, epic).and_return(false)

      results = resolve_recent_items(current_user: user)

      expect(results).to be_empty
    end

    it 'includes epics the user can read' do
      allow(epic_service).to receive(:latest_with_timestamps).and_return({
        epic => 1.hour.ago
      })

      allow(Ability).to receive(:allowed?).with(user, :read_epic, epic).and_return(true)

      results = resolve_recent_items(current_user: user)

      expect(results).to have_attributes(size: 1)
      expect(results.first.item).to eq(epic)
    end

    it 'handles mixed authorization correctly across all item types' do
      allow(issue_service).to receive(:latest_with_timestamps).and_return({
        issue => 3.hours.ago
      })
      allow(mr_service).to receive(:latest_with_timestamps).and_return({
        merge_request => 2.hours.ago
      })
      allow(epic_service).to receive(:latest_with_timestamps).and_return({
        epic => 1.hour.ago
      })

      # Mixed authorization: user can read issue and epic, but not MR due to SAML
      allow(Ability).to receive(:allowed?).with(user, :read_issue, issue).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_merge_request, merge_request).and_return(false)
      allow(Ability).to receive(:allowed?).with(user, :read_epic, epic).and_return(true)

      results = resolve_recent_items(current_user: user)

      # Should only return issue and epic, MR should be filtered out
      expect(results).to have_attributes(size: 2)
      expect(results.map(&:item)).to contain_exactly(issue, epic)
      # Should be sorted by timestamp (epic first, then issue)
      expect(results.map(&:item)).to eq([epic, issue])
    end

    it 'returns empty array when user cannot read any items due to SAML expiry' do
      allow(issue_service).to receive(:latest_with_timestamps).and_return({
        issue => 2.hours.ago
      })
      allow(epic_service).to receive(:latest_with_timestamps).and_return({
        epic => 1.hour.ago
      })

      # Simulate SAML authorization failure for all items
      allow(Ability).to receive(:allowed?).with(user, :read_issue, issue).and_return(false)
      allow(Ability).to receive(:allowed?).with(user, :read_epic, epic).and_return(false)

      results = resolve_recent_items(current_user: user)

      expect(results).to be_empty
    end
  end

  def resolve_recent_items(current_user:)
    resolve(described_class, obj: current_user, ctx: { current_user: current_user })
  end
end
