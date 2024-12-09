# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TestHooks::ProjectService, feature_category: :code_testing do
  include AfterNextHelpers

  let(:current_user) { create(:user) }

  describe '#execute' do
    let_it_be(:project) { create(:project, :repository) }

    let(:hook) { create(:project_hook, project: project) }
    let(:trigger) { 'not_implemented_events' }
    let(:service) { described_class.new(hook, current_user, trigger) }
    let(:success_result) { { status: :success, http_status: 200, message: 'ok' } }

    context 'for vulnerability_events' do
      let(:trigger) { 'vulnerability_events' }
      let(:trigger_key) { :vulnerability_hooks }

      it 'executes hook' do
        freeze_time do
          expected_data = {
            object_kind: "vulnerability",
            object_attributes: {
              url: "#{project.web_url}/-/security/vulnerabilities/1",
              title: 'REXML DoS vulnerability',
              state: 'confirmed',
              project_id: project.id,
              location: {
                'file' => 'Gemfile.lock',
                'dependency' => { 'package' => { 'name' => 'rexml' }, 'version' => '3.3.1' }
              },
              cvss: [
                {
                  'vector' => 'CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:H',
                  'vendor' => 'NVD'
                }
              ],
              severity: 'high',
              severity_overridden: false,
              identifiers: [
                {
                  name: 'Gemnasium-29dce398-220a-4315-8c84-16cd8b6d9b05',
                  external_id: '29dce398-220a-4315-8c84-16cd8b6d9b05',
                  external_type: 'gemnasium',
                  url: 'https://gitlab.com/gitlab-org/security-products/gemnasium-db/-/blob/master/gem/rexml/CVE-2024-41123.yml'
                },
                {
                  name: 'CVE-2024-41123',
                  external_id: 'CVE-2024-41123',
                  external_type: 'cve',
                  url: 'https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2024-41123'
                }
              ],
              report_type: "dependency_scanning",
              confidence: "unknown",
              confidence_overridden: false,
              confirmed_at: Time.current,
              confirmed_by_id: current_user.id,
              dismissed_at: nil,
              dismissed_by_id: nil,
              resolved_on_default_branch: false,
              created_at: Time.current,
              updated_at: Time.current
            }
          }

          expect(hook).to receive(:execute).with(expected_data, trigger_key, force: true).and_return(success_result)
          expect(service.execute).to include(success_result)
        end
      end
    end
  end
end
