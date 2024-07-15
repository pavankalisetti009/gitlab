# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240704125425_add_label_ids_to_merge_request.rb')

RSpec.describe AddLabelIdsToMergeRequest, :elastic, feature_category: :global_search do
  let(:version) { 20240704125425 }

  include_examples 'migration adds mapping'
end
