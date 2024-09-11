# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WikiPage::Meta, feature_category: :wiki do
  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }

  before do
    stub_licensed_features(group_wikis: true)
  end

  include_examples 'creating wiki page meta record examples' do
    let(:container) { group }
    let(:other_container) { other_group }
  end
end
