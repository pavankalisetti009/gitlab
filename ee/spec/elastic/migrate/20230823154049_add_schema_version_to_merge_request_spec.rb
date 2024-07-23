# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230823154049_add_schema_version_to_merge_request.rb')

RSpec.describe AddSchemaVersionToMergeRequest, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230823154049
end
