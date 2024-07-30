# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230724070100_backfill_epics.rb')

RSpec.describe BackfillEpics, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230724070100
end
