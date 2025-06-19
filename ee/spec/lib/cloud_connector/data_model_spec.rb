# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Cloud Connector data model', feature_category: :cloud_connector do
  # Tests a regression where cached state was leaking between tests.
  # This test should remain green as long as cached state is wiped between tests,
  # which currently happens in a `before` rule in `spec_helper.rb`.
  context 'with resetting cached state' do
    it 'is always empty when not on gitlab.com' do
      # This should always be empty since this will read from the database,
      # and we have not inserted the respective records.
      ::Gitlab::CloudConnector::DataModel::Base.descendants.each do |clazz|
        expect(clazz.all).to be_empty
      end
    end

    it 'is never empty when on gitlab.com', :saas do
      # This should never be empty since this should read from a file
      # on disk that is never empty.
      ::Gitlab::CloudConnector::DataModel::Base.descendants.each do |clazz|
        expect(clazz.all).not_to be_empty
      end
    end
  end
end
