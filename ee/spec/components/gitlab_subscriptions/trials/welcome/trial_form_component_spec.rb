# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::Welcome::TrialFormComponent, :aggregate_failures, feature_category: :acquisition do
  let(:user) { build(:user, user_detail_organization: 'Acme Corp') }
  let(:form_params) do
    {
      glm_source: 'some-source',
      glm_content: 'some-content'
    }.with_indifferent_access
  end

  let(:registration_objective_options) do
    [
      { value: "0", text: "I want to learn the basics of Git" },
      { value: "1", text: "I want to move my repository to GitLab from somewhere else" },
      { value: "2", text: "I want to store my code" },
      { value: "3", text: "I want to explore GitLab to see if it's worth switching to" },
      { value: "4", text: "I want to use GitLab CI with my existing repository" },
      { value: "5", text: "A different reason" }
    ]
  end

  let(:kwargs) do
    {
      user: user,
      params: form_params
    }
  end

  subject(:component) { render_inline(described_class.new(**kwargs)) && page }

  context 'with default content' do
    let(:expected_form_data_attributes) do
      {
        userData: {
          firstName: '',
          lastName: '',
          emailDomain: user.email_domain,
          companyName: user.user_detail_organization,
          groupName: '',
          projectName: '',
          country: '',
          state: ''
        },
        submitPath: users_sign_up_trial_welcome_path(glm_source: 'some-source', glm_content: 'some-content'),
        gtmSubmitEventLabel: 'saasTrialSubmit'
      }.with_indifferent_access
    end

    it { is_expected.to have_content('Welcome to GitLab') }

    it 'has body content' do
      is_expected
        .to have_content('Welcome to GitLab Help us personalize your GitLab experience by answering a few questions')
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end

    it 'includes role options' do
      view_model = parsed_view_model
      expect(view_model['roleOptions']).to include(hash_including('value' => '0', 'text' => 'Software Developer'))
      expect(view_model['roleOptions']).to include(hash_including('value' => '8', 'text' => 'Other'))
    end

    it 'includes registration objective options' do
      view_model = parsed_view_model
      expect(view_model['registrationObjectiveOptions']).to include(hash_including('value' => '0',
        'text' => 'I want to learn the basics of Git'))
      expect(view_model['registrationObjectiveOptions']).to include(hash_including('value' => '5',
        'text' => 'A different reason'))
    end

    it 'includes all user data fields' do
      view_model = parsed_view_model
      user_data = view_model['userData']

      expect(user_data['firstName']).to eq('')
      expect(user_data['lastName']).to eq('')
      expect(user_data['emailDomain']).to eq(user.email_domain)
      expect(user_data['companyName']).to eq(user.user_detail_organization)
      expect(user_data['groupName']).to eq('')
      expect(user_data['projectName']).to eq('')
      expect(user_data['country']).to eq('')
      expect(user_data['state']).to eq('')
    end

    it 'includes submit path with all parameters' do
      view_model = parsed_view_model
      expected_path = users_sign_up_trial_welcome_path(glm_source: 'some-source', glm_content: 'some-content')

      expect(view_model['submitPath']).to eq(expected_path)
    end

    it 'includes GTM event label' do
      view_model = parsed_view_model
      expect(view_model['gtmSubmitEventLabel']).to eq('saasTrialSubmit')
    end
  end

  context 'when glm_params are not provided' do
    let(:form_params) { {}.with_indifferent_access }
    let(:expected_form_data_attributes) do
      {
        userData: {
          firstName: '',
          lastName: '',
          emailDomain: user.email_domain,
          companyName: user.user_detail_organization,
          groupName: '',
          projectName: '',
          country: '',
          state: ''
        },
        submitPath: users_sign_up_trial_welcome_path,
        gtmSubmitEventLabel: 'saasTrialSubmit'
      }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end

    it 'excludes GLM params from submit path' do
      view_model = parsed_view_model
      submit_path = view_model['submitPath']

      expect(submit_path).not_to include('glm_source')
      expect(submit_path).not_to include('glm_content')
    end

    it 'includes role options' do
      view_model = parsed_view_model
      expect(view_model['roleOptions']).to include(hash_including('value' => '0', 'text' => 'Software Developer'))
      expect(view_model['roleOptions']).to include(hash_including('value' => '8', 'text' => 'Other'))
    end

    it 'includes registration objective options' do
      view_model = parsed_view_model
      expect(view_model['registrationObjectiveOptions']).to include(
        hash_including('value' => '0', 'text' => 'I want to learn the basics of Git')
      )
      expect(view_model['registrationObjectiveOptions']).to include(
        hash_including('value' => '5', 'text' => 'A different reason')
      )
    end
  end

  describe 'user data variations' do
    context 'when user has no organization' do
      let(:user) { build(:user, user_detail_organization: nil) }

      it 'handles nil organization gracefully' do
        view_model = parsed_view_model
        expect(view_model.dig('userData', 'companyName')).to be_nil
      end
    end

    context 'when user has blank organization' do
      let(:user) { build(:user, user_detail_organization: '') }

      it 'handles blank organization' do
        view_model = parsed_view_model
        expect(view_model.dig('userData', 'companyName')).to eq('')
      end
    end
  end

  describe 'form data structure' do
    it 'generates valid JSON' do
      view_model = parsed_view_model
      expect(view_model).to be_a(Hash)
    end

    it 'includes all required top-level keys' do
      view_model = parsed_view_model

      expect(view_model).to have_key('userData')
      expect(view_model).to have_key('submitPath')
      expect(view_model).to have_key('gtmSubmitEventLabel')
    end

    it 'has userData as a hash' do
      view_model = parsed_view_model
      expect(view_model['userData']).to be_a(Hash)
    end

    it 'has submitPath as a string' do
      view_model = parsed_view_model
      expect(view_model['submitPath']).to be_a(String)
    end

    it 'has gtmSubmitEventLabel as a string' do
      view_model = parsed_view_model
      expect(view_model['gtmSubmitEventLabel']).to be_a(String)
    end

    it 'includes all required userData fields' do
      view_model = parsed_view_model
      user_data = view_model['userData']

      expected_keys = %w[firstName lastName emailDomain companyName groupName projectName country state]
      expect(user_data.keys).to match_array(expected_keys)
    end

    it 'includes role and registration objective options' do
      view_model = parsed_view_model

      expect(view_model).to have_key('roleOptions')
      expect(view_model).to have_key('registrationObjectiveOptions')
      expect(view_model['roleOptions']).to be_an(Array)
      expect(view_model['registrationObjectiveOptions']).to be_an(Array)
      expect(view_model['roleOptions'].length).to eq(9)
      expect(view_model['registrationObjectiveOptions'].length).to eq(6)
    end
  end

  describe 'parameter handling edge cases' do
    context 'with only glm_source provided' do
      let(:form_params) { { glm_source: 'partial-source' }.with_indifferent_access }

      it 'includes partial GLM params in submit path' do
        view_model = parsed_view_model
        submit_path = view_model['submitPath']

        expect(submit_path).to include('glm_source=partial-source')
        expect(submit_path).not_to include('glm_content')
      end
    end

    context 'with only glm_content provided' do
      let(:form_params) { { glm_content: 'partial-content' }.with_indifferent_access }

      it 'includes partial GLM params in submit path' do
        view_model = parsed_view_model
        submit_path = view_model['submitPath']

        expect(submit_path).to include('glm_content=partial-content')
        expect(submit_path).not_to include('glm_source')
      end
    end

    context 'with additional unrecognized params' do
      let(:form_params) do
        {
          glm_source: 'some-source',
          glm_content: 'some-content',
          random_param: 'should-be-ignored'
        }.with_indifferent_access
      end

      it 'only includes recognized params in submit path' do
        view_model = parsed_view_model
        submit_path = view_model['submitPath']

        expect(submit_path).to include('glm_source=some-source')
        expect(submit_path).to include('glm_content=some-content')
        expect(submit_path).not_to include('random_param')
      end
    end
  end

  def parsed_view_model
    actual_element = component.find('#js-create-trial-welcome-form')
    data_view_model = actual_element['data-view-model']
    ::Gitlab::Json.parse(data_view_model)
  end

  def expect_form_data_attribute(data_attributes)
    view_model = parsed_view_model

    data_attributes.each do |attribute, value|
      expect(view_model[attribute]).to eq(value)
    end
  end
end
