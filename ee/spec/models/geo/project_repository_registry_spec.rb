# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectRepositoryRegistry, :geo, type: :model, feature_category: :geo_replication do
  let(:model_record_key) { :project }
  let(:model_record) { create(:project_with_repo) }
  let(:model_record_id) { model_record.id }
  let(:project) { model_record }

  context 'for project repository replication v1' do
    include_examples 'Geo::ProjectRepositoryRegistry'
  end
end
