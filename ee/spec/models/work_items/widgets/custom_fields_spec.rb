# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::CustomFields, feature_category: :team_planning do
  let_it_be(:work_item) { create(:work_item, :issue) }

  describe '#custom_field_values' do
    subject { described_class.new(work_item).custom_field_values }

    it { is_expected.to eq([]) }
  end
end
