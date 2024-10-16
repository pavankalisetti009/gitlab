# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AdjournedProjectDeletionWorker, feature_category: :groups_and_projects do
  describe "#perform" do
    subject(:worker) { described_class.new }

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, deleting_user: user, owners: user) }
    let(:service) { instance_double(Projects::DestroyService) }

    shared_examples 'executes destroying project' do
      specify do
        expect(service).to receive(:async_execute)
        expect(Projects::DestroyService).to receive(:new).with(project, user).and_return(service)

        worker.perform(project.id)
      end
    end

    it_behaves_like 'executes destroying project'

    context 'when an admin deletes the project', :enable_admin_mode do
      let_it_be(:user) { create(:admin) }

      before do
        project.update!(deleting_user: user)
      end

      it_behaves_like 'executes destroying project'
    end

    it 'stops execution if user was deleted' do
      project.update!(deleting_user: nil)

      expect(Projects::DestroyService).not_to receive(:new)

      worker.perform(project.id)
    end
  end
end
