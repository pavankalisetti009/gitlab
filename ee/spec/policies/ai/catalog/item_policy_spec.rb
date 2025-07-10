# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemPolicy, feature_category: :duo_chat do
  subject(:policy) { described_class.new(current_user, item) }

  let_it_be(:developer) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:project) { create(:project, developers: developer, guests: guest) }

  describe 'read_ai_catalog_item' do
    let(:current_user) { developer }

    context 'with private item' do
      let_it_be(:item) { create(:ai_catalog_item, project: project, public: false) }

      context 'when developer' do
        it { is_expected.to be_allowed(:read_ai_catalog_item) }
      end

      context 'when guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:read_ai_catalog_item) }
      end

      context 'with global_ai_catalog feature flag disabled' do
        before do
          stub_feature_flags(global_ai_catalog: false)
        end

        it { is_expected.to be_disallowed(:read_ai_catalog_item) }
      end
    end

    context 'with public item' do
      let_it_be(:item) { create(:ai_catalog_item, project: project, public: true) }

      context 'when no user' do
        let(:current_user) { nil }

        it { is_expected.to be_allowed(:read_ai_catalog_item) }
      end

      context 'with global_ai_catalog feature flag disabled' do
        before do
          stub_feature_flags(global_ai_catalog: false)
        end

        it { is_expected.to be_disallowed(:read_ai_catalog_item) }
      end
    end
  end
end
