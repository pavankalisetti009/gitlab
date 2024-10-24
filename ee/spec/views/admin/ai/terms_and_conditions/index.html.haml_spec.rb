# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/ai/terms_and_conditions/index.html.haml', feature_category: :"self-hosted_models" do
  subject { render && rendered }

  it do
    is_expected.to have_link('self-hosted models',
      href: '/help/administration/self_hosted_models/index.md')
  end

  it { is_expected.to have_link('Accept GitLab Testing Agreement', href: admin_ai_terms_and_conditions_url) }
  it { is_expected.to have_link('GitLab Testing Agreement', href: 'https://about.gitlab.com/handbook/legal/testing-agreement/') }
end
