# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Workloads::Workload, feature_category: :continuous_integration do
  describe 'associations' do
    it { is_expected.to have_many(:workflows_workloads).class_name('Ai::DuoWorkflows::WorkflowsWorkload') }
    it { is_expected.to have_many(:workflows).through(:workflows_workloads) }
  end
end
