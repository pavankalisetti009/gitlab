# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::HostedRunner, feature_category: :hosted_runners do
  let_it_be(:runner) { create(:ci_runner) }

  describe 'associations' do
    it { is_expected.to belong_to(:runner).class_name('Ci::Runner') }
  end

  describe 'validations' do
    subject { build(:ci_hosted_runner) }

    it { is_expected.to validate_presence_of(:runner) }
    it { is_expected.to validate_uniqueness_of(:runner_id) }
  end
end
