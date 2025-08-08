# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Backups::Finding, feature_category: :vulnerability_management do
  it_behaves_like 'a vulnerability retention policy backup model',
    mappings: { project_id: :project_id, vulnerability_id: :vulnerability_id }
end
