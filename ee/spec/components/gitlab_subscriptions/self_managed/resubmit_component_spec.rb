# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::ResubmitComponent, feature_category: :acquisition do
  it_behaves_like GitlabSubscriptions::Trials::ResubmitComponent
end
