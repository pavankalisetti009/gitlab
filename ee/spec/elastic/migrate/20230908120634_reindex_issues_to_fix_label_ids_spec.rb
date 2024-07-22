# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230908120634_reindex_issues_to_fix_label_ids.rb')

RSpec.describe ReindexIssuesToFixLabelIds, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230908120634
end
