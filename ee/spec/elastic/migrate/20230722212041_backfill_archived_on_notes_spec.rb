# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230722212041_backfill_archived_on_notes.rb')

RSpec.describe BackfillArchivedOnNotes, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230722212041
end
