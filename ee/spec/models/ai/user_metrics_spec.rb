# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UserMetrics, feature_category: :ai_abstraction_layer do
  it { is_expected.to belong_to(:user).required }
end
