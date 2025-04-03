# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250226195021_create_vulnerabilities_index.rb')

RSpec.describe CreateVulnerabilitiesIndex, :elastic, feature_category: :vulnerability_management do
  it_behaves_like 'migration creates a new index', 20250226195021, Vulnerability
end
