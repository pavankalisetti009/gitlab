# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::DependenciesController, feature_category: :dependency_management do
  describe 'GET #index' do
    let_it_be(:developer) { create(:user) }
    let_it_be(:guest) { create(:user) }
    let_it_be(:project) { create(:project, :repository, :private) }

    let(:params) { {} }

    before do
      project.add_developer(developer)
      project.add_guest(guest)

      sign_in(user)
    end

    include_context '"Security and compliance" permissions' do
      let(:user) { developer }
      let(:valid_request) { get project_dependencies_path(project) }
    end

    context 'with authorized user' do
      context 'when feature is available' do
        before do
          stub_licensed_features(dependency_scanning: true, license_scanning: true, security_dashboard: true)
        end

        context 'when project has sbom_occurrences' do
          let(:user) { developer }

          let_it_be(:occurrences) { create_list(:sbom_occurrence, 3, project: project) }

          before do
            get project_dependencies_path(project, **params, format: :json)
          end

          it 'returns data based on sbom occurrences' do
            expected = occurrences.map do |occurrence|
              {
                'occurrence_id' => occurrence.id,
                'vulnerability_count' => occurrence.vulnerability_count,
                'name' => occurrence.name,
                'packager' => occurrence.packager,
                'version' => occurrence.version,
                'location' => occurrence.location,
                'licenses' => [::Gitlab::LicenseScanning::PackageLicenses::UNKNOWN_LICENSE]
              }.deep_stringify_keys
            end

            expect(json_response['dependencies']).to match_array(expected)
          end

          it 'avoids N+1 queries' do
            control_count = ActiveRecord::QueryRecorder
              .new { get project_dependencies_path(project, **params, format: :json) }.count
            create_list(:sbom_occurrence, 2, project: project)

            expect { get project_dependencies_path(project, **params, format: :json) }
              .not_to exceed_query_limit(control_count)
          end

          context 'with source types filter' do
            let_it_be(:os_occurrence) { create(:sbom_occurrence, :os_occurrence, project: project) }
            let_it_be(:registry_occurrence) { create(:sbom_occurrence, :registry_occurrence, project: project) }

            context 'when source_types param is present' do
              let(:params) { { source_types: [:container_scanning_for_registry] } }

              it 'returns data based on filtered sbom occurrences' do
                expect(json_response['dependencies']).to match_array(
                  hash_including('occurrence_id' => registry_occurrence.id))
              end
            end

            context 'when source_types param is empty' do
              let(:params) { { source_types: [] } }

              it 'returns data based on DEFAULT_SOURCES' do
                expected = ([os_occurrence] + occurrences).map { |o| hash_including('occurrence_id' => o.id) }
                expect(json_response['dependencies']).to match_array(expected)
              end
            end
          end

          context 'when sorted by packager' do
            let_it_be(:occurrences) do
              [
                create(:sbom_occurrence, :bundler, project: project),
                create(:sbom_occurrence, :npm, project: project),
                create(:sbom_occurrence, :yarn, project: project)
              ]
            end

            let(:params) do
              {
                sort_by: 'packager',
                sort: verse,
                page: 1
              }
            end

            context 'in descending order' do
              let(:verse) { 'desc' }

              it 'returns sorted list' do
                expect(json_response['dependencies']).to be_sorted(by: :packager, verse: :desc)
              end
            end

            context 'in ascending order' do
              let(:verse) { 'asc' }

              it 'returns sorted list' do
                expect(json_response['dependencies']).to be_sorted(by: :packager, verse: :asc)
              end
            end
          end

          context 'when sorted by severity' do
            let_it_be(:critical) { create(:sbom_occurrence, highest_severity: :critical, project: project) }
            let_it_be(:high) { create(:sbom_occurrence, highest_severity: :high, project: project) }
            let_it_be(:low) { create(:sbom_occurrence, highest_severity: :low, project: project) }

            let(:params) do
              {
                sort_by: 'severity',
                sort: verse,
                page: 1
              }
            end

            context 'in ascending order' do
              let(:verse) { 'asc' }

              it 'returns sorted list' do
                nulls = json_response['dependencies'].first(3)
                sorted = json_response['dependencies'].last(3)
                expect(sorted.pluck('occurrence_id')).to eq([low.id, high.id, critical.id])
                expect(nulls.pluck('occurrence_id')).to match_array(occurrences.pluck(:id))
              end
            end

            context 'in descending order' do
              let(:verse) { 'desc' }

              it 'returns sorted list' do
                sorted = json_response['dependencies'].first(3)
                nulls = json_response['dependencies'].last(3)
                expect(sorted.pluck('occurrence_id')).to eq([critical.id, high.id, low.id])
                expect(nulls.pluck('occurrence_id')).to match_array(occurrences.pluck(:id))
              end
            end
          end
        end

        it_behaves_like 'tracks govern usage event', 'users_visiting_dependencies' do
          let(:request) { get project_dependencies_path(project, format: :html) }
        end
      end

      context 'when licensed feature is unavailable' do
        let(:user) { developer }

        it 'returns 403 for a JSON request' do
          get project_dependencies_path(project, format: :json)

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'returns a 404 for an HTML request' do
          get project_dependencies_path(project, format: :html)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it_behaves_like "doesn't track govern usage event", 'users_visiting_dependencies' do
          let(:request) { get project_dependencies_path(project, format: :html) }
        end
      end
    end

    context 'with unauthorized user' do
      let(:user) { guest }

      before do
        stub_licensed_features(dependency_scanning: true)

        project.add_guest(user)
      end

      it 'returns 403 for a JSON request' do
        get project_dependencies_path(project, format: :json)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'returns a 404 for an HTML request' do
        get project_dependencies_path(project, format: :html)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like "doesn't track govern usage event", 'users_visiting_dependencies' do
        let(:request) { get project_dependencies_path(project, format: :html) }
      end
    end
  end
end
