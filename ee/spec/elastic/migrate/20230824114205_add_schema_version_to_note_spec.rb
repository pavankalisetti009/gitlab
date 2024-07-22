# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230824114205_add_schema_version_to_note.rb')

RSpec.describe AddSchemaVersionToNote, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230824114205
end
