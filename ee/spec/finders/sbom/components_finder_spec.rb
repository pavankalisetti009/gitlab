# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentsFinder, feature_category: :vulnerability_management do
  let(:finder) { described_class.new(query) }
  let_it_be(:component_1) { create(:sbom_component, name: "activerecord") }
  let_it_be(:component_2) { create(:sbom_component, name: "activejob") }
  let_it_be(:component_3) { create(:sbom_component, name: "activestorage") }
  let_it_be(:component_4) { create(:sbom_component, name: "activesupport") }

  describe '#execute' do
    subject(:find) { finder.execute }

    context 'when given no query string' do
      let(:query) { nil }

      it "returns all Sbom::Components" do
        expect(find).to match_array([component_1, component_2, component_3, component_4])
      end

      context 'when there is more than maximum limit Sbom::Components' do
        before do
          stub_const("#{described_class}::DEFAULT_MAX_RESULTS", 3)
          create_list(:sbom_component, described_class::DEFAULT_MAX_RESULTS)
        end

        it 'does not return more than Sbom::Component::DEFAULT_MAX_RESULTS results' do
          expect(Sbom::Component.count).to be > described_class::DEFAULT_MAX_RESULTS
          expect(find.length).to be <= described_class::DEFAULT_MAX_RESULTS
        end
      end
    end

    context 'when given a query string' do
      let(:query) { "actives" }

      it "returns all matching Sbom::Components" do
        expect(find).to match_array([component_3, component_4])
      end
    end
  end
end
