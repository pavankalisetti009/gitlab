# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::SelfManaged::StatusWidgetPresenter, feature_category: :acquisition do
  describe '#attributes' do
    subject(:attributes) { described_class.new.attributes }

    it { is_expected.to eq({}) }
  end
end
