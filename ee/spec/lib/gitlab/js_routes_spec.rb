# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::JsRoutes, feature_category: :tooling do
  describe '.generate!' do
    let_it_be(:expected_base_path) do
      Rails.root.join('ee/app/assets/javascripts/lib/utils/path_helpers')
    end

    before_all do
      described_class.generate!
    end

    it 'splits path helpers by namespace' do
      expect(File).to exist(File.join(expected_base_path, 'project.js'))
      expect(File).to exist(File.join(expected_base_path, 'group.js'))
    end
  end
end
