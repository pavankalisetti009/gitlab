# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240814223217_add_issues_access_level_in_work_item_index.rb')

RSpec.describe AddIssuesAccessLevelInWorkItemIndex, :elastic, feature_category: :global_search do
  let(:version) { 20240814223217 }

  include_examples 'migration adds mapping'
end
