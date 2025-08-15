# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'profiles/preferences/show' do
  before do
    assign(:user, user)
    allow(controller).to receive(:current_user).and_return(user)
    stub_feature_flags(enable_hamilton_in_user_preferences: false)
  end

  let(:user) { create_default(:user) }

  context 'security dashboard feature is available' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    it 'renders the group view choice preference' do
      render

      expect(rendered).to have_select('Group overview content')
    end
  end

  context 'security dashboard feature is unavailable' do
    it 'does not render the group view choice preference' do
      render

      expect(rendered).not_to have_select('Group overview content')
    end
  end

  context 'Default Duo namespace assignments' do
    context 'when user does not have any Duo namespace assignments' do
      before do
        allow(view).to receive(:user_duo_namespace_assignment_options).and_return([])
      end

      it 'does not have a default Duo group input' do
        render

        expect(rendered).not_to have_select _('Default GitLab Duo namespace')
      end
    end

    context 'when user has 1 or more Duo namespace assignments' do
      before do
        user_duo_namespace_assignments = [['Namespace 1', 1], ['Namespace 2', 2]]
        allow(view).to receive(:user_duo_namespace_assignment_options).and_return(user_duo_namespace_assignments)
      end

      context 'with no namespace selected' do
        it 'renders select input with placeholder text' do
          render

          expect(rendered).to have_select _('Default GitLab Duo namespace'),
            options: ['Select a default Duo namespace...', 'Namespace 1', 'Namespace 2']
        end
      end

      context 'with default already selected' do
        before do
          allow_next_instance_of(UserPreference) do |preference|
            allow(preference).to receive(:default_duo_add_on_assignment_id).and_return(1)
          end
        end

        it 'renders select input with namespace options' do
          render

          expect(rendered).to have_select _('Default GitLab Duo namespace'),
            options: ['Namespace 1', 'Namespace 2']
        end
      end
    end
  end

  context 'Code Suggestions self-assignment', :saas, feature_category: :code_suggestions do
    context 'when the feature is available' do
      before do
        stub_feature_flags(enable_hamilton_in_user_preferences: user)
      end

      it 'renders the code suggestions preference' do
        render

        expect(rendered).to render_template('profiles/preferences/_code_suggestions_settings_self_assignment')
        field_text = s_('Preferences|Code Suggestions')
        expect(rendered).to have_content(field_text)
      end
    end

    context 'when the feature is not available' do
      it 'does not render the code suggestions preference' do
        render

        expect(rendered).to render_template('profiles/preferences/_code_suggestions_settings_self_assignment')
        field_text = s_('Preferences|Code Suggestions')
        expect(rendered).not_to have_content(field_text)
      end
    end
  end
end
