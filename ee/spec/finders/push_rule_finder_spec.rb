# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PushRuleFinder, feature_category: :source_code_management do
  subject(:push_rule_finder) { described_class.new }

  let_it_be(:global_push_rule) { create(:push_rule_sample) }

  describe "#execute" do
    it "finds the global push rule" do
      expect(push_rule_finder.execute).to eq(global_push_rule)
    end
  end
end
