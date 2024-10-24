# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Groups::AdjournedDeletionService, feature_category: :groups_and_projects do
  let_it_be(:delay) { 1.hour }
  let_it_be(:params) { { delay: delay } }
  let_it_be_with_reload(:group) { create(:group) }
  let(:resource) { group }

  subject(:service) { described_class.new(group: group, current_user: user, params: params) }

  def ensure_destroy_worker_scheduled
    expect(GroupDestroyWorker).to receive(:perform_in).with(delay, group.id, user.id)
  end

  include_examples 'adjourned deletion service'
end
