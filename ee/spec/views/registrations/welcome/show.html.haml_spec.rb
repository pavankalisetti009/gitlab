# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'registrations/welcome/show', feature_category: :onboarding do
  let(:hide_setup_for_company_field?) { false }
  let(:show_joining_project?) { true }
  let(:show_opt_in_to_email?) { true }
  let(:onboarding_status) do
    instance_double(
      ::Onboarding::Status,
      hide_setup_for_company_field?: hide_setup_for_company_field?,
      setup_for_company_label_text: '_text_',
      setup_for_company_help_text: '_help_text_',
      show_joining_project?: show_joining_project?,
      show_opt_in_to_email?: show_opt_in_to_email?,
      welcome_submit_button_text: '_button_text_'
    )
  end

  before do
    allow(view).to receive(:onboarding_status).and_return(onboarding_status)
    allow(view).to receive(:current_user).and_return(build_stubbed(:user))
    controller.params[:glm_content] = '_glm_content_'
    controller.params[:glm_source] = '_glm_source_'

    render
  end

  subject { rendered }

  context 'with basic form items' do
    it do
      is_expected.to have_css('form[action="/users/sign_up/welcome?glm_content=_glm_content_&glm_source=_glm_source_"]')
    end

    it 'the text for the :setup_for_company label' do
      is_expected.to have_selector('label[for="user_setup_for_company"]', text: '_text_')
    end

    it 'shows the text for the submit button' do
      is_expected.to have_button('_button_text_')
    end

    it 'has the joining_project fields' do
      is_expected.to have_selector('#joining_project_true')
    end

    it 'has the hidden opt in to email field' do
      is_expected.to have_selector('input[name="user[onboarding_status_email_opt_in]"]')
    end

    it 'renders a select and text field for additional information' do
      is_expected.to have_selector('select[name="user[registration_objective]"]')
      is_expected.to have_selector('input[name="jobs_to_be_done_other"]', visible: false)
    end
  end

  context 'when setup for company field should be hidden' do
    let(:hide_setup_for_company_field?) { true }

    it 'does not have setup_for_company label' do
      is_expected.not_to have_selector('label[for="user_setup_for_company"]')
    end

    it 'the text for the :setup_for_company help text' do
      is_expected.not_to have_text('_help_text_')
    end

    it 'has a hidden input for setup_for_company' do
      is_expected.to have_field('user[setup_for_company]', type: :hidden)
    end
  end

  context 'when not showing joining project' do
    let(:show_joining_project?) { false }

    it 'does not have the joining_project fields' do
      is_expected.not_to have_selector('#joining_project_true')
    end
  end

  context 'when not showing opt in to email' do
    let(:show_opt_in_to_email?) { false }

    it 'does not have opt in to email field' do
      is_expected.not_to have_selector('input[name="user[onboarding_status_email_opt_in]"]')
    end
  end

  context 'when setup for company field is not hidden' do
    let(:hide_setup_for_company_field?) { false }

    it 'has setup_for_company label' do
      is_expected.to have_selector('label[for="user_setup_for_company"]')
    end

    it 'the text for the :setup_for_company help text' do
      is_expected.to have_text('_help_text_')
    end
  end
end
