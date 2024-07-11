# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Panel, feature_category: :navigation do
  let_it_be(:user) { build(:admin) }

  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

  before do
    stub_licensed_features(
      custom_roles: true,
      admin_audit_log: true,
      custom_file_templates: true,
      elastic_search: true,
      license_scanning: true,
      product_analytics: true
    )
    stub_application_setting(grafana_enabled: true)
  end

  subject { described_class.new(context) }

  it_behaves_like 'a panel with uniquely identifiable menu items'
  it_behaves_like 'a panel without placeholders'
  it_behaves_like 'a panel instantiable by the anonymous user'

  shared_examples 'hides code suggestions menu' do
    it 'does not render code suggestions menu' do
      expect(menus).not_to include(instance_of(::Sidebars::Admin::Menus::CodeSuggestionsMenu))
    end
  end

  shared_examples 'hides ai-powered features menu' do
    it 'does not render ai-powered features menu' do
      expect(menus).not_to include(instance_of(::Sidebars::Admin::Menus::AiPoweredFeaturesMenu))
    end
  end

  describe '#configure_menus' do
    let(:menus) { subject.instance_variable_get(:@menus) }
    let(:license) { build(:license, plan: License::PREMIUM_PLAN) }

    before do
      allow(License).to receive(:current).and_return(license)
    end

    context 'when instance is self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when instance has a paid license' do
        it 'renders ai-powered features menu' do
          expect(menus).to include(instance_of(::Sidebars::Admin::Menus::AiPoweredFeaturesMenu))
        end

        it_behaves_like 'hides code suggestions menu'

        context 'when ai_custom_model feature is disabled' do
          before do
            stub_feature_flags(ai_custom_model: false)
          end

          it 'renders code suggestions menu' do
            expect(menus).to include(instance_of(::Sidebars::Admin::Menus::CodeSuggestionsMenu))
          end

          it_behaves_like 'hides ai-powered features menu'
        end
      end

      context 'when instance has no paid license' do
        let(:license) { nil }

        it_behaves_like 'hides code suggestions menu'
        it_behaves_like 'hides ai-powered features menu'
      end
    end

    context 'when instance is SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it_behaves_like 'hides code suggestions menu'
      it_behaves_like 'hides ai-powered features menu'
    end
  end
end
