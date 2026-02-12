# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackagesHelmMetadataCacheReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:helm_metadata_cache) }

  include_examples 'a blob replicator'
end
