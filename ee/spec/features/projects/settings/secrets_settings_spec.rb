# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project settings > CI / CD > Secrets', :js, feature_category: :secrets_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }
  let(:secrets_manager) { build(:project_secrets_manager, project: project) }

  describe 'secrets settings section' do
    describe 'when feature flag and secrets manager are both enabled and a maintainer visits the setting' do
      before do
        sign_in(maintainer)
        stub_feature_flags(ci_tanukey_ui: true)
        secrets_manager.save!
        visit project_settings_ci_cd_path(project)
      end

      subject { page.has_selector?('#js-secrets-settings') }

      it { is_expected.to be(true) }
    end

    where(:user, :feature_flag_value) do
      ref(:maintainer) | false
      ref(:reporter)   | true
      ref(:reporter)   | false
    end

    with_them do
      before do
        sign_in(user)
        stub_feature_flags(ci_tanukey_ui: feature_flag_value)
        visit project_settings_ci_cd_path(project)
      end

      subject { page.has_selector?('#js-secrets-settings') }

      it { is_expected.to be(false) }
    end
  end
end
