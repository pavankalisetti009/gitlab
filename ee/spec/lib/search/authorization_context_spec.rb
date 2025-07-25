# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::AuthorizationContext, feature_category: :global_search do
  let(:current_user) { build(:user) }
  let(:context) { described_class.new(current_user) }

  describe '#traversal_ids_for_user' do
    let(:options) { { search_level: :project, group_ids: [1, 2], features: [:foo], min_access_level: 10 } }
    let(:stubbed_value) { ["123-456-", "789-012-"] }

    it 'calls Elastic::Filters.traversal_ids_for_user with current_user and options' do
      expect(context).to receive(:traversal_ids_for_user)
        .with(current_user, options).and_return(stubbed_value)
      expect(context.get_traversal_ids_for_user(options)).to eq(stubbed_value)
    end
  end

  describe '#project_ids_for_user' do
    let(:options) { { search_level: :group, group_ids: [3, 4] } }
    let(:stubbed_value) { [99, 100] }

    it 'calls Elastic::Filters.project_ids_for_user with current_user and options' do
      expect(context).to receive(:project_ids_for_user)
        .with(current_user, options).and_return(stubbed_value)
      expect(context.get_project_ids_for_user(options)).to eq(stubbed_value)
    end
  end
end
