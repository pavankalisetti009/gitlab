# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241105111645_add_work_item_type_correct_id.rb')

RSpec.describe AddWorkItemTypeCorrectId, :elastic, feature_category: :global_search do
  let(:version) { 20241105111645 }

  include_examples 'migration adds mapping'
end
