# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PushRuleFinder, feature_category: :source_code_management do
  subject(:push_rule_finder) { described_class.new(organization) }

  let_it_be(:organization) { create(:organization) }
  let_it_be(:global_push_rule) { create(:push_rule_sample) }

  describe "#execute" do
    context "when looking up OrganizationPushRule" do
      context "when container is not passed" do
        let(:organization) { nil }

        it "returns global push rule" do
          expect(push_rule_finder.execute).to eq(global_push_rule)
        end
      end

      context "when organization has an OrganizationPushRule" do
        let!(:organization_push_rule) { create(:organization_push_rule, organization: organization) }

        it "finds the organization push rule" do
          expect(push_rule_finder.execute).to eq(organization_push_rule)
        end
      end

      context "when organization has no push rule" do
        it "returns nil" do
          expect(push_rule_finder.execute).to be_nil
        end
      end
    end
  end
end
