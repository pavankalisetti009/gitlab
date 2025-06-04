# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::Protection::Concerns::TagRule, feature_category: :container_registry do
  let(:test_class) do
    Class.new do
      include ContainerRegistry::Protection::Concerns::TagRule

      public :protected_for_delete?
    end
  end

  let(:service) { test_class.new }
  let_it_be(:current_user) { create(:user) }

  describe '#protected_for_delete?' do
    let_it_be_with_refind(:project) { create(:project) }

    subject(:protected_by_rules) { service.protected_for_delete?(project:, current_user:) }

    context 'when licensed feature is available' do
      before do
        stub_licensed_features(container_registry_immutable_tag_rules: true)
      end

      context 'when immutable tag rules present' do
        before_all do
          create(:container_registry_protection_tag_rule, :immutable, tag_name_pattern: 'a', project: project)
        end

        context 'when has tags' do
          before do
            allow(project).to receive(:has_container_registry_tags?).and_return(true)
          end

          it { is_expected.to be true }

          context 'when current_user is an admin', :enable_admin_mode do
            let(:current_user) { build_stubbed(:admin) }

            it { is_expected.to be true }
          end
        end

        context 'when no tags' do
          before do
            allow(project).to receive(:has_container_registry_tags?).and_return(false)
          end

          it { is_expected.to be(false) }
        end
      end

      context 'when no immutable tag rules' do
        it_behaves_like 'checking for mutable tag rules'
      end
    end

    context 'when licensed feature is not available' do
      before do
        stub_licensed_features(container_registry_immutable_tag_rules: false)
      end

      it_behaves_like 'checking for mutable tag rules'
    end

    context 'when feature is disabled' do
      before do
        stub_feature_flags(container_registry_immutable_tags: false)
      end

      it_behaves_like 'checking for mutable tag rules'
    end
  end
end
