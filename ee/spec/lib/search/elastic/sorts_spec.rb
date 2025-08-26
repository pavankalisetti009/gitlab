# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Sorts, feature_category: :global_search do
  let(:query_hash) { {} }

  describe '#sort_by' do
    using RSpec::Parameterized::TableSyntax

    subject(:sort_by) { described_class.sort_by(query_hash: query_hash, options: options) }

    where(:doc_type, :order_by, :sort, :expected) do
      'issue' | nil | nil | { sort: {} }
      'issue' | 'created_at' | 'asc' | { sort: { created_at: { order: 'asc' } } }
      'issue' | 'created_at' | 'desc' | { sort: { created_at: { order: 'desc' } } }
      'issue' | 'updated_at' | 'asc' | { sort: { updated_at: { order: 'asc' } } }
      'issue' | 'updated_at' | 'desc' | { sort: { updated_at: { order: 'desc' } } }
      'issue' | 'popularity' | 'asc' | { sort: { upvotes: { order: 'asc' } } }
      'issue' | 'popularity' | 'desc' | { sort: { upvotes: { order: 'desc' } } }
      'issue' | 'milestone_due' | 'asc' | { sort: { milestone_due_date: { order: 'asc' } } }
      'issue' | 'milestone_due' | 'desc' | { sort: { milestone_due_date: { order: 'desc' } } }
      'issue' | 'weight' | 'asc' | { sort: { weight: { order: 'asc' } } }
      'issue' | 'weight' | 'desc' | { sort: { weight: { order: 'desc' } } }
      'issue' | 'health_status' | 'asc' | { sort: { health_status: { order: 'asc' } } }
      'issue' | 'health_status' | 'desc' | { sort: { health_status: { order: 'desc' } } }
      'issue' | 'closed_at' | 'asc' | { sort: { closed_at: { order: 'asc' } } }
      'issue' | 'closed_at' | 'desc' | { sort: { closed_at: { order: 'desc' } } }
      'issue' | 'due_date' | 'asc' | { sort: { due_date: { order: 'asc' } } }
      'issue' | 'due_date' | 'desc' | { sort: { due_date: { order: 'desc' } } }
      'issue' | nil | 'created_asc' | { sort: { created_at: { order: 'asc' } } }
      'issue' | nil | 'created_desc' | { sort: { created_at: { order: 'desc' } } }
      'issue' | nil | 'updated_asc' | { sort: { updated_at: { order: 'asc' } } }
      'issue' | nil | 'updated_desc' | { sort: { updated_at: { order: 'desc' } } }
      'issue' | nil | 'popularity_asc' | { sort: { upvotes: { order: 'asc' } } }
      'issue' | nil | 'popularity_desc' | { sort: { upvotes: { order: 'desc' } } }
      'issue' | nil | 'milestone_due_asc' | { sort: { milestone_due_date: { order: 'asc' } } }
      'issue' | nil | 'milestone_due_desc' | { sort: { milestone_due_date: { order: 'desc' } } }
      'issue' | nil | 'weight_asc' | { sort: { weight: { order: 'asc' } } }
      'issue' | nil | 'weight_desc' | { sort: { weight: { order: 'desc' } } }
      'issue' | nil | 'health_status_asc' | { sort: { health_status: { order: 'asc' } } }
      'issue' | nil | 'health_status_desc' | { sort: { health_status: { order: 'desc' } } }
      'issue' | nil | 'closed_at_asc' | { sort: { closed_at: { order: 'asc' } } }
      'issue' | nil | 'closed_at_desc' | { sort: { closed_at: { order: 'desc' } } }
      'issue' | nil | 'due_date_asc' | { sort: { due_date: { order: 'asc' } } }
      'issue' | nil | 'due_date_desc' | { sort: { due_date: { order: 'desc' } } }
      'foo' | 'popularity' | 'asc' | { sort: {} }
      'foo' | 'popularity' | 'desc' | { sort: {} }
      'foo' | nil | 'popularity_asc' | { sort: {} }
      'foo' | nil | 'popularity_desc' | { sort: {} }
    end

    with_them do
      let(:options) { { doc_type: doc_type, order_by: order_by, sort: sort } }

      it { is_expected.to eq(expected) }
    end
  end
end
