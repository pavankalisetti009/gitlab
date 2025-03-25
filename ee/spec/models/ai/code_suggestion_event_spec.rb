# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CodeSuggestionEvent, feature_category: :code_suggestions do
  subject(:event) { described_class.new(attributes) }

  let(:attributes) { { event: 'code_suggestion_shown_in_ide' } }
  let_it_be(:user) { create(:user) }
  let_it_be(:default_organization) { create(:organization, :default) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:user) }

  it_behaves_like 'common ai_usage_event'

  describe '.payload_attributes' do
    it 'has list of payload attributes' do
      expect(described_class.payload_attributes).to match_array(
        %w[language suggestion_size unique_tracking_id branch_name]
      )
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:timestamp) }

    it 'validates presence of organization_id' do
      allow(Organizations::Organization).to receive(:default_organization).and_return(nil)

      expect(event).not_to allow_value(nil).for(:organization_id)
    end

    it do
      is_expected.not_to allow_value(5.months.ago).for(:timestamp).with_message(_('must be 3 months old at the most'))
    end
  end

  describe '#timestamp', :freeze_time do
    it 'defaults to current time' do
      expect(event.timestamp).to eq(DateTime.current)
    end

    it 'properly converts from string' do
      expect(described_class.new(timestamp: DateTime.current.to_s).timestamp).to eq(DateTime.current)
    end
  end

  describe '#organization_id' do
    subject { described_class.new(user: user) }

    it { is_expected.to populate_sharding_key(:organization_id).with(default_organization.id) }

    context 'when user belongs to an organization' do
      let(:user_organization) do
        create(:organization).tap { |org| create(:organization_user, organization: org, user: user) }
      end

      it { is_expected.to populate_sharding_key(:organization_id).with(user_organization.id) }
    end
  end

  describe '#to_clickhouse_csv_row', :freeze_time do
    let(:attributes) do
      super().merge(
        user: user,
        timestamp: 1.day.ago,
        payload: {
          suggestion_size: 3,
          language: 'foo',
          unique_tracking_id: 'bar',
          branch_name: 'main'
        }
      )
    end

    it 'returns serialized attributes hash' do
      expect(event.to_clickhouse_csv_row).to eq({
        user_id: user.id,
        event: described_class.events[:code_suggestion_shown_in_ide],
        timestamp: 1.day.ago.to_f,
        suggestion_size: 3,
        language: 'foo',
        unique_tracking_id: 'bar',
        branch_name: 'main'
      })
    end
  end

  describe '#store_to_pg', :freeze_time do
    context 'when the model is invalid' do
      it 'does not add anything to write buffer' do
        expect(Ai::UsageEventWriteBuffer).not_to receive(:add)

        event.store_to_pg
      end
    end

    context 'when the model is valid' do
      let(:attributes) do
        super().merge(
          user: user,
          timestamp: 1.day.ago,
          payload: {
            suggestion_size: 3,
            language: 'foo',
            unique_tracking_id: 'bar'
          }
        )
      end

      it 'adds model attributes to write buffer' do
        expect(Ai::UsageEventWriteBuffer).to receive(:add)
          .with('Ai::CodeSuggestionEvent', {
            event: 'code_suggestion_shown_in_ide',
            timestamp: 1.day.ago,
            user_id: user.id,
            organization_id: default_organization.id,
            payload: {
              suggestion_size: 3,
              language: 'foo',
              unique_tracking_id: 'bar'
            }
          }.with_indifferent_access)

        event.store_to_pg
      end
    end
  end
end
