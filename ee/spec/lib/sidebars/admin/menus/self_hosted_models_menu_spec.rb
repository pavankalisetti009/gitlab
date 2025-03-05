# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::SelfHostedModelsMenu, feature_category: :navigation do
  it_behaves_like 'Admin menu',
    link: '/admin/ai/duo_self_hosted',
    title: s_('Admin|GitLab Duo Self-Hosted'),
    icon: 'machine-learning'

  it_behaves_like 'Admin menu without sub menus', active_routes: { controller: :duo_self_hosted }
end
