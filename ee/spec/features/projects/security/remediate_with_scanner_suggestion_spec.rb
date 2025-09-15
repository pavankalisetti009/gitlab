# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Remediate with scanner suggestion", :js, feature_category: :vulnerability_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }
  let_it_be(:pipeline) { create(:ee_ci_pipeline, project: project) }

  let_it_be(:finding) do
    create(:vulnerabilities_finding, project: project, initial_finding_pipeline: pipeline)
  end

  let_it_be(:remediation) { create(:vulnerabilities_remediation, project: project, findings: [finding]) }

  let_it_be(:vulnerability) do
    create(:vulnerability, findings: [finding], title: "SAST vulnerability", project: project)
  end

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
    sign_in(user)
  end

  context 'when user clicks "Resolve with scanner suggestion"' do
    before do
      visit vulnerability_url(vulnerability)
    end

    def resolve_with_scanner_suggestion
      click_button 'Resolutions'
      click_button 'Resolve with scanner suggestion', max_wait_time: 45
    end

    it 'creates MR and redirects to it' do
      expect { resolve_with_scanner_suggestion }.to change { project.reload.merge_requests.count }.from(0).to(1)

      mr_path = project_merge_request_path(project, project.merge_requests.last)
      expect(page).to have_current_path(mr_path)
      expect(page).to have_content 'Resolve vulnerability: Cipher with no integrity'
    end
  end
end
