# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectSecuritySettings, :aggregate_failures, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:security_setting) { create(:project_security_setting, project: project) }
  let(:url) { "/projects/#{project.id}/security_settings" }

  describe 'GET /projects/:id/security_settings' do
    context 'when user is not authenticated' do
      it 'returns 401 Unauthorized' do
        get api(url)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        stub_licensed_features(secret_push_protection: true)
      end

      it 'returns project security settings when the user has at least the Developer role' do
        project.add_developer(user)
        get api(url, user)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'returns 401 Unauthorized when the user has Guest role' do
        project.add_guest(user)
        get api(url, user)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'returns 404 for non-existing project' do
        project.add_developer(user)
        get api("/projects/non-existing/security_settings", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PUT /projects/:id/security_settings' do
    context 'when user is not authenticated' do
      it 'returns 401 Unauthorized' do
        put api(url)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      context 'when the user is a Maintainer' do
        before do
          project.add_maintainer(user)
        end

        context 'with ultimate license' do
          before do
            stub_licensed_features(secret_push_protection: true)
          end

          it 'updates project security settings using the secret_push_protection_enabled param' do
            put api(url, user), params: { secret_push_protection_enabled: true }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['secret_push_protection_enabled']).to be(true)
          end

          it 'updates project security settings using the pre_receive_secret_detection_enabled param' do
            put api(url, user), params: { pre_receive_secret_detection_enabled: true }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['secret_push_protection_enabled']).to be(true)
          end
        end

        context 'without ultimate license' do
          before do
            stub_licensed_features(secret_push_protection: false)
          end

          context 'on GitLab.com', :saas do
            context 'when project is public' do
              before do
                stub_saas_features(auto_enable_secret_push_protection_public_projects: true)
                project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
              end

              it 'updates project security settings for public projects' do
                put api(url, user), params: { secret_push_protection_enabled: true }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['secret_push_protection_enabled']).to be(true)
              end
            end

            context 'when project is private' do
              before do
                project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
              end

              it 'returns 403 Forbidden for private projects' do
                put api(url, user), params: { secret_push_protection_enabled: true }

                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end

            context 'when project is internal' do
              before do
                project.update!(visibility_level: Gitlab::VisibilityLevel::INTERNAL)
              end

              it 'returns 403 Forbidden for internal projects' do
                put api(url, user), params: { secret_push_protection_enabled: true }

                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end
          end

          context 'when not on GitLab.com' do
            before do
              stub_saas_features(auto_enable_secret_push_protection_public_projects: false)
            end

            it 'returns 403 Forbidden' do
              put api(url, user), params: { secret_push_protection_enabled: true }

              expect(response).to have_gitlab_http_status(:forbidden)
            end
          end
        end

        context 'when project is archived' do
          before do
            project.update!(archived: true)
          end

          it 'returns 403 forbidden' do
            put api(url, user), params: { secret_push_protection_enabled: true }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'when projects group is archived' do
          let(:group) { create(:group, :archived) }
          let(:project) { create(:project, group: group) }

          before do
            project.add_maintainer(user)
          end

          it 'returns 403 forbidden' do
            put api(url, user), params: { secret_push_protection_enabled: true }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end
      end

      context 'when the user is a Developer' do
        before do
          project.add_developer(user)
          stub_licensed_features(secret_push_protection: true)
        end

        it 'returns 401 Unauthorized for users with Developer role' do
          put api(url, user), params: { secret_push_protection_enabled: true }

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end
    end
  end

  describe 'license and visibility checks' do
    context 'with Ultimate license' do
      before do
        project.add_developer(user)
        stub_licensed_features(secret_push_protection: true)
      end

      it 'allows access for public project' do
        project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)

        get api(url, user)
        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'allows access for private project' do
        project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)

        get api(url, user)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'without Ultimate license' do
      before do
        project.add_developer(user)
        stub_saas_features(auto_enable_secret_push_protection_public_projects: true)
        stub_licensed_features(secret_push_protection: false)
      end

      context 'for public .com project', :saas do
        before do
          project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
        end

        it 'allows access' do
          get api(url, user)
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'for private project' do
        before do
          project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
        end

        it 'returns 403 Forbidden' do
          get api(url, user)
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when feature flag is disabled' do
        before do
          project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
          stub_feature_flags(auto_spp_public_com_projects: false)
        end

        it 'returns 403 Forbidden even for public projects' do
          get api(url, user)
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when saas feature is disabled' do
        before do
          stub_saas_features(auto_enable_secret_push_protection_public_projects: false)
          project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
        end

        it 'returns 403 Forbidden even for public projects' do
          get api(url, user)
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end
end
