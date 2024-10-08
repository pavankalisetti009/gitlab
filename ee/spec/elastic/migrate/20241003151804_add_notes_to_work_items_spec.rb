# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241003151804_add_notes_to_work_items.rb')

RSpec.describe AddNotesToWorkItems, :elastic, feature_category: :global_search do
  let(:version) { 20241003151804 }

  include_examples 'migration adds mapping'
end
