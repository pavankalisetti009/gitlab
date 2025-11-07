# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/db/active_context/migrate/20251029093927_drop_code.rb')

RSpec.describe DropCode, feature_category: :code_suggestions do
  let(:version) { 20251029093927 }
  let(:migration) { ::ActiveContext::Migration::Dictionary.instance.find_by_version(version) }
  let(:executor) { instance_double(ActiveContext::Databases::Elasticsearch::Executor, drop_collection: true) }
  let(:adapter) { instance_double(ActiveContext::Databases::Elasticsearch::Adapter, executor: executor) }

  subject(:migrate) { migration.new.migrate! }

  it 'drops the code collection' do
    expect(ActiveContext).to receive(:adapter).and_return(adapter)
    migrate
  end
end
