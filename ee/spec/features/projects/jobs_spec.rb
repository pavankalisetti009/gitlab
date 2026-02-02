# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe 'Jobs', :clean_gitlab_redis_shared_state, feature_category: :continuous_integration do
  let(:user) { create(:user) }
  let(:user_access_level) { :developer }
  let(:pipeline) { create(:ci_pipeline, project: project) }

  let(:job) { create(:ci_build, :trace_live, pipeline: pipeline) }

  before do
    stub_application_setting(ci_job_live_trace_enabled: true)
    project.add_role(user, user_access_level)
    sign_in(user)
  end

  describe "GET /:project/jobs/:id", :js do
    context 'when job is not running', :js do
      let(:job) { create(:ci_build, :success, :trace_artifact, pipeline: pipeline) }
      let(:project) { create(:project, :repository) }

      context 'when namespace is in read-only mode' do
        before do
          # Trigger read-only mode via storage limit to avoid association loading issues with direct Namespace stubbing
          allow_next_instance_of(::Namespaces::Storage::RootSize) do |size_checker|
            allow(size_checker).to receive(:above_size_limit?).and_return(true)
          end
        end

        it 'does not show retry button' do
          visit project_job_path(project, job)
          wait_for_requests

          expect(page).not_to have_link('Retry')
          expect(page).to have_content('Job succeeded')
        end
      end
    end
  end
end
