# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230720000000_reindex_wikis_to_fix_routing.rb')

RSpec.describe ReindexWikisToFixRouting, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230720000000
end
