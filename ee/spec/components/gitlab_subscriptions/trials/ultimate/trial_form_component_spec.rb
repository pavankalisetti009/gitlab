# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::Ultimate::TrialFormComponent, :saas, :aggregate_failures, type: :component, feature_category: :acquisition do
  let(:user) { build(:user) }
  let(:form_params) do
    {
      glm_source: 'some-source',
      glm_content: 'some-content',
      namespace_id: 1
    }.with_indifferent_access
  end

  let(:kwargs) { { user: user, params: form_params } }

  subject(:component) { render_inline(described_class.new(**kwargs)) && page }

  context 'with default content' do
    let(:expected_form_data_attributes) do
      {
        userData: {
          firstName: user.first_name,
          lastName: user.last_name,
          emailDomain: user.email_domain,
          companyName: user.organization,
          showNameFields: false,
          phoneNumber: nil,
          country: '',
          state: ''
        },
        submitPath: trials_path(step: 'lead', glm_source: 'some-source', glm_content: 'some-content', namespace_id: 1),
        gtmSubmitEventLabel: 'saasTrialSubmit'
      }.with_indifferent_access
    end

    it { is_expected.to have_content(s_('Trial|Start your free trial')) }

    it 'has body content' do
      is_expected
        .to have_content(s_('Trial|We need a few more details from you to activate your trial.'))
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end

    it 'has advantages section' do
      is_expected.to have_content(s_('InProductMarketing|No credit card required.'))
    end
  end

  context 'when namespace_id is not provided' do
    let(:form_params) { super().except(:namespace_id) }
    let(:expected_form_data_attributes) do
      {
        submitPath: trials_path(step: 'lead', glm_source: 'some-source', glm_content: 'some-content')
      }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  context 'when glm_params are not provided' do
    let(:form_params) { super().except(:glm_source, :glm_content) }
    let(:expected_form_data_attributes) do
      { submitPath: trials_path(step: 'lead', namespace_id: 1) }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  def expect_form_data_attribute(data_attributes)
    data_attributes.each do |attribute, value|
      actual_element = component.find('#js-create-trial-form')
      data_view_model = actual_element['data-view-model']
      parsed_view_model = ::Gitlab::Json.parse(data_view_model)

      expect(parsed_view_model).to have_key(attribute)
      expect(parsed_view_model[attribute]).to eq(value)
    end
  end
end
