# frozen_string_literal: true

RSpec.shared_examples 'adding promotion_request_count in app data' do
  context 'when pending_members_count is nil' do
    let!(:pending_members_count) { nil }

    it 'returns `promotion_request_count` property with []' do
      expect(helper_app_data[:promotion_request]).to include({ total_items: nil })
    end
  end

  context 'when pending_members is not nil' do
    let!(:pending_members_count) do
      create_list(:member_approval, 2, type, member_namespace: member_namespace)
    end

    it 'returns valid `promotion_request_count`' do
      expect(helper_app_data[:promotion_request].keys).to match_array([:total_items])
    end
  end
end
