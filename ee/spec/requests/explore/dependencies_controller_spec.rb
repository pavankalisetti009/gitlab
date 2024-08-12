# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Explore::DependenciesController, feature_category: :dependency_management do
  describe 'GET #index' do
    describe 'GET index.html' do
      subject { get explore_dependencies_path }

      context 'when dependency scanning is available' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        context 'when user is admin', :enable_admin_mode do
          let_it_be(:user) { create(:user, :admin) }
          let_it_be(:organization) { create(:organization, :default) }

          before do
            sign_in(user)
          end

          include_examples 'returning response status', :ok

          context 'when the feature flag is disabled' do
            before do
              stub_feature_flags(explore_dependencies: false)
            end

            include_examples 'returning response status', :not_found
          end
        end

        context 'when user is not admin' do
          let_it_be(:user) { create(:user, :without_default_org) }

          before do
            sign_in(user)
          end

          include_examples 'returning response status', :forbidden
        end

        context 'when the user is a member the default organization' do
          let_it_be_with_reload(:user) { create(:user, :without_default_org) }
          let_it_be(:organization) { create(:organization, :default) }
          let_it_be(:organization_user) { create(:organization_user, organization: organization, user: user) }

          before do
            sign_in(user)
          end

          include_examples 'returning response status', :ok

          it_behaves_like 'tracks govern usage event', 'users_visiting_dependencies' do
            let(:request) { subject }
          end

          context 'when loading a specific page of results' do
            let_it_be(:per_page) { 1 }
            let_it_be(:group) { create(:group, organization: organization) }
            let_it_be(:project) { create(:project, organization: organization, group: group) }
            let_it_be(:occurrences) { create_list(:sbom_occurrence, 3 * per_page, :mit, project: project) }
            let_it_be(:ordered_occurrences) { Sbom::Occurrence.order(:id) }
            let(:cursor) { ordered_occurrences.keyset_paginate(cursor: nil, per_page: per_page).cursor_for_next_page }

            before_all do
              project.add_developer(user)
            end

            it 'assigns pagination info' do
              get explore_dependencies_path(cursor: cursor, per_page: per_page)

              paginator = ordered_occurrences.keyset_paginate(cursor: cursor, per_page: per_page)
              expect(Gitlab::Json.parse(assigns(:page_info))).to eql({
                "type" => "cursor",
                "has_next_page" => true,
                "has_previous_page" => true,
                "start_cursor" => paginator.cursor_for_previous_page,
                "current_cursor" => cursor,
                "end_cursor" => paginator.cursor_for_next_page
              })
            end
          end
        end

        context 'when a user is not logged in' do
          include_examples 'returning response status', :not_found
        end
      end

      context 'when dependency scanning is not available' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        include_examples 'returning response status', :not_found

        context 'when user is admin', :enable_admin_mode do
          let_it_be(:user) { create(:user, :admin) }
          let_it_be(:organization) { create(:organization, :default) }

          before do
            sign_in(user)
          end

          include_examples 'returning response status', :forbidden
        end
      end
    end

    describe 'GET index.json', :enable_admin_mode do
      subject { get explore_dependencies_path, as: :json }

      context 'when dependency scanning is available' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        context 'when user is admin', :enable_admin_mode do
          let_it_be(:user) { create(:user, :admin) }
          let_it_be(:organization) { create(:organization, :default) }
          let_it_be(:group) { create(:group, organization: organization) }
          let_it_be(:project) { create(:project, organization: organization, group: group) }

          before do
            sign_in(user)
          end

          context "with occurrences" do
            let_it_be(:per_page) { 20 }
            let_it_be(:occurrences) { create_list(:sbom_occurrence, 2 * per_page, :mit, project: project) }
            let(:cursor) { Sbom::Occurrence.order(:id).keyset_paginate(per_page: per_page).cursor_for_next_page }

            it 'renders a JSON response', :aggregate_failures do
              get explore_dependencies_path(cursor: cursor), as: :json

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to include_keyset_url_params
              expect(response).to include_limited_pagination_headers

              expect(response.headers['X-Page-Type']).to eql('cursor')
              expect(response.headers['X-Per-Page']).to eql(per_page)

              expected_occurrences = occurrences[per_page...(per_page + per_page)].map do |occurrence|
                {
                  'name' => occurrence.name,
                  'packager' => occurrence.packager,
                  'version' => occurrence.version,
                  'location' => occurrence.location.as_json,
                  'occurrence_id' => occurrence.id,
                  'vulnerability_count' => occurrence.vulnerability_count
                }
              end
              expect(json_response["dependencies"]).to match_array(expected_occurrences)
            end
          end

          it 'avoids N+1 database queries' do
            get explore_dependencies_path, as: :json # warmup

            create(:sbom_occurrence, project: project)

            control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
              get explore_dependencies_path, as: :json
            end

            create_list(:project, 3, organization: organization).each do |project|
              create(:sbom_occurrence, project: project)
            end

            expect do
              get explore_dependencies_path, as: :json
            end.not_to exceed_query_limit(control)
          end

          include_examples 'returning response status', :ok
        end

        context 'when user is a member of some projects in the organization' do
          let_it_be(:user) { create(:user) }
          let_it_be(:organization) { create(:organization, :default) }
          let_it_be(:group) { create(:group, organization: organization) }
          let_it_be(:project_a) { create(:project, organization: organization, group: group) }
          let_it_be(:project_b) { create(:project, organization: organization, group: group) }

          let_it_be(:occurrence_a) { create(:sbom_occurrence, project: project_a) }
          let_it_be(:occurrence_b) { create(:sbom_occurrence, project: project_b) }

          before do
            sign_in(user)
          end

          before_all do
            project_a.add_developer(user)
          end

          it 'returns the dependencies from the projects that the user has access to' do
            get explore_dependencies_path, as: :json

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response["dependencies"]).to match_array([
              {
                'name' => occurrence_a.name,
                'packager' => occurrence_a.packager,
                'version' => occurrence_a.version,
                'location' => occurrence_a.location.as_json,
                'occurrence_id' => occurrence_a.id,
                'vulnerability_count' => occurrence_a.vulnerability_count
              }
            ])
          end

          it 'loads data using the InOperatorOptimization query' do
            control = ActiveRecord::QueryRecorder.new do
              get explore_dependencies_path, as: :json
            end

            expect(control.log_message).to include('FROM "recursive_keyset_cte" AS "sbom_occurrences"')
          end
        end

        context 'when the user is not a member of the default organization' do
          let_it_be(:user) { create(:user, :without_default_org) }

          before do
            sign_in(user)
          end

          include_examples 'returning response status', :forbidden
        end

        context 'when a user is not logged in' do
          include_examples 'returning response status', :not_found
        end
      end

      context 'when dependency scanning is not available' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        include_examples 'returning response status', :not_found

        context 'when user is admin', :enable_admin_mode do
          let_it_be(:user) { create(:user, :admin) }
          let_it_be(:organization) { create(:organization, :default) }

          before do
            sign_in(user)
          end

          include_examples 'returning response status', :forbidden
        end
      end
    end
  end
end
