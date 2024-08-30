# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Usage Quotas > Code Suggestions tab', :js, :saas, feature_category: :seat_cost_management do
  it_behaves_like 'Gitlab Duo administration' do
    let(:duo_page) { group_usage_quotas_path(group, anchor: 'code-suggestions-usage-tab') }
  end
end
