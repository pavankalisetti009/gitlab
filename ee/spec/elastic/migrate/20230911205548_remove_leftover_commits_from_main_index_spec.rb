# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230911205548_remove_leftover_commits_from_main_index.rb')

RSpec.describe RemoveLeftoverCommitsFromMainIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230911205548
end
