# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoEnterprise::LegacyTrialFormComponent, :saas, :aggregate_failures, feature_category: :acquisition do
  let(:additional_kwargs) { {} }

  it_behaves_like described_class
end
