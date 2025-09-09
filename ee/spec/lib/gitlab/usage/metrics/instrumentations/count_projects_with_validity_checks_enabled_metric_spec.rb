# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsWithValidityChecksEnabledMetric, feature_category: :service_ping do
  let(:expected_value) { 3 }

  before do
    projects = create_list(:project, 3)
    projects.each { |project| project.security_setting.update!(validity_checks_enabled: true) }
    create(:project)
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'all', data_source: 'database' }
end
