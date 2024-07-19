# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230831152648_backfill_archived_on_milestones.rb')

RSpec.describe BackfillArchivedOnMilestones, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230831152648
end
