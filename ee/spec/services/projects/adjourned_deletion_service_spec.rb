# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::AdjournedDeletionService, feature_category: :groups_and_projects do
  let(:project) { create(:project, marked_for_deletion_at: 10.days.ago, marked_for_deletion_by_user_id: user&.id) }
  let(:resource) { project }

  subject(:service) { described_class.new(project: project, current_user: user) }

  def ensure_destroy_worker_scheduled
    expect(ProjectDestroyWorker).to receive(:perform_async).with(project.id, user.id, {})
  end

  include_examples 'adjourned deletion service'

  context 'when user cannot remove the project', :sidekiq_inline do
    context 'with deleted user' do
      let(:user) { nil }

      it_behaves_like 'user cannot remove'
    end
  end
end
