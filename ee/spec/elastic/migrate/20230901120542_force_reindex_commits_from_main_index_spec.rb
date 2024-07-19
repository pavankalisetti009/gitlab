# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230901120542_force_reindex_commits_from_main_index.rb')

RSpec.describe ForceReindexCommitsFromMainIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230901120542
end
