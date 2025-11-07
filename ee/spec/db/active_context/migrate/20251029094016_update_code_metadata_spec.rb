# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/db/active_context/migrate/20251029094016_update_code_metadata.rb')

RSpec.describe UpdateCodeMetadata, feature_category: :code_suggestions do
  let(:version) { 20251029094016 }
  let(:migration) { ::ActiveContext::Migration::Dictionary.instance.find_by_version(version) }
  let_it_be(:collection) { create(:ai_active_context_collection, name: 'gitlab_active_context_code') }

  subject(:migrate) { migration.new.migrate! }

  it 'sets indexing_embedding_versions on the collection' do
    expect { migrate }.to change { collection.reload.indexing_embedding_versions }.from(nil).to([1])
  end

  it 'sets search_embedding_version on the collection' do
    expect { migrate }.to change { collection.reload.search_embedding_version }.from(nil).to(1)
  end
end
