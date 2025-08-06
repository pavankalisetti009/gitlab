# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Admin::DataManagement, :aggregate_failures, :request_store, :geo, :api, feature_category: :geo_replication do
  include ApiHelpers
  include EE::GeoHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  describe 'GET /data_management/:model_name' do
    context 'with feature flag enabled' do
      context 'when authenticated as admin' do
        context 'with valid model name' do
          it 'returns matching object data' do
            expected_model = create(:snippet_repository)

            get api("/admin/data_management/snippet_repository", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.first).to include('id' => expected_model.id,
              'model_class' => expected_model.class.name)
          end

          context 'with pagination and ordering' do
            it 'paginates results correctly' do
              create_list(:snippet_repository, 9)

              get api("/admin/data_management/snippet_repository?per_page=5", admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(5)
              expect(response.headers['X-Next-Page']).to eq('2')
              expect(response.headers['X-Page']).to eq('1')
              expect(response.headers['X-Per-Page']).to eq('5')

              get api("/admin/data_management/snippet_repository?per_page=5&page=2", admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response.size).to eq(4) # Remaining 4 records
              expect(response.headers['X-Page']).to eq('2')
              expect(response.headers['X-Next-Page']).to be_empty
            end

            it 'handles pagination with ordering correctly' do
              create_list(:project, 10)

              get api("/admin/data_management/project?per_page=3", admin, admin_mode: true)
              first_page_ids = json_response.pluck('id')

              get api("/admin/data_management/project?per_page=3&page=2", admin, admin_mode: true)
              second_page_ids = json_response.pluck('id')

              # Verify ordering is maintained across pages
              expect(first_page_ids).to eq(first_page_ids.sort)
              expect(second_page_ids).to eq(second_page_ids.sort)
              expect(first_page_ids.last).to be < second_page_ids.first
            end
          end
        end

        context 'with case variations' do
          it 'returns 400 for uppercase model names' do
            get api('/admin/data_management/LFS_OBJECT', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end

          it 'returns 400 for mixed case model names' do
            get api('/admin/data_management/Lfs_Object', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'with invalid model names' do
          # Edge cases - invalid inputs
          it 'returns 400 for non-existent model name' do
            get api('/admin/data_management/non_existent_model', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end

          it 'returns 404 for empty model name' do
            get api('/admin/data_management/', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:not_found)
          end

          it 'raises an error for model name with spaces' do
            expect { get api('/admin/data_management/lfs object', admin, admin_mode: true) }
              .to raise_error(URI::InvalidURIError)
          end
        end

        context 'with boundary length inputs' do
          # Boundary cases - very long strings
          it 'handles very long model names gracefully' do
            long_model_name = 'a' * 1000
            get api("/admin/data_management/#{long_model_name}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end

          it 'handles single character model name' do
            get api('/admin/data_management/a', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'with URL encoding' do
          # Edge cases - URL encoded characters
          it 'handles URL encoded model names' do
            get api('/admin/data_management/lfs%5Fobject', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'handles URL encoded special characters' do
            get api('/admin/data_management/lfs%40object', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when model exists but no records' do
          it 'returns the model class even when no records exist' do
            get api("/admin/data_management/upload", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq([])
          end
        end
      end

      context 'when not authenticated as admin' do
        # Security boundary tests
        it 'denies access for regular users' do
          get api('/admin/data_management/lfs_object', user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'denies access for unauthenticated requests' do
          get api('/admin/data_management/lfs_object')

          expect(response).to have_gitlab_http_status(:unauthorized)
        end

        it 'denies access for admin without admin mode' do
          get api('/admin/data_management/lfs_object', admin)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when ModelMapper raises exceptions' do
        # Edge cases - error handling
        it 'handles ModelMapper exceptions gracefully' do
          allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name)
                                               .and_raise(StandardError)

          get api('/admin/data_management/lfs_object', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:internal_server_error)
        end

        it 'handles nil return from ModelMapper' do
          allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name)
                                               .and_return(nil)

          get api('/admin/data_management/lfs_object', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with all available replicable models' do
        where(model_classes: Gitlab::Geo::Replicator.subclasses.map(&:model))

        with_them do
          let(:model_name) { Gitlab::Geo::ModelMapper.convert_to_name(model_classes) }
          let(:factory) { factory_name(model_classes) }

          it 'handles all known replicable model names' do
            get api("/admin/data_management/#{model_name}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'orders results by primary key' do
            create_list(factory, 5)

            get api("/admin/data_management/snippet_repository", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)

            # Extract IDs from response and verify they're in ascending order
            response_ids = json_response.pluck('id')
            expect(response_ids).to eq(response_ids.sort)
          end
        end
      end
    end

    context 'with feature flag disabled' do
      before do
        Feature.disable(:geo_primary_verification_view)
      end

      it 'returns 404' do
        get api("/admin/data_management/lfs_object", admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /admin/data_management/:model_name/:id' do
    context 'with feature flag enabled' do
      context 'with valid model name' do
        let(:expected_model) { create(:snippet_repository) }

        context 'with valid id' do
          it 'returns matching object data' do
            get api("/admin/data_management/snippet_repository/#{expected_model.id}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include('id' => expected_model.id, 'model_class' => expected_model.class.name)
          end
        end

        context 'with invalid id' do
          it 'returns 404 when ID is 0' do
            get api("/admin/data_management/snippet_repository/0", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:not_found)
          end

          it 'returns 400 when ID is not integer' do
            get api("/admin/data_management/snippet_repository/random", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end

          it 'returns 400 when ID is alphanumeric containing valid ID' do
            get api("/admin/data_management/snippet_repository/rand#{expected_model.id}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context 'with invalid model names' do
        # Edge cases - invalid inputs
        it 'returns 400 for non-existent model name' do
          get api('/admin/data_management/non_existent_model/1', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it 'returns 400 for empty model name' do
          get api('/admin/data_management//1', admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it 'raises an error for model name with spaces' do
          expect { get api('/admin/data_management/lfs object/1', admin, admin_mode: true) }
            .to raise_error(URI::InvalidURIError)
        end
      end

      context 'when model exists but no records' do
        it 'returns not_found when no records exist' do
          get api("/admin/data_management/upload/1", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with all available replicable models' do
        where(model_classes: Gitlab::Geo::Replicator.subclasses.map(&:model))

        with_them do
          let(:model_name) { Gitlab::Geo::ModelMapper.convert_to_name(model_classes) }
          let(:expected_record) { create(factory_name(model_classes)) } # rubocop:disable Rails/SaveBang -- factory

          it 'handles all known replicable model names' do
            get api("/admin/data_management/#{model_name}/#{expected_record.id}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include('id' => expected_record.id, 'model_class' => expected_record.class.name)
          end
        end
      end
    end

    context 'when not authenticated as admin' do
      # Security boundary tests
      it 'denies access for regular users' do
        get api('/admin/data_management/project/1', user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'denies access for unauthenticated requests' do
        get api('/admin/data_management/project/1')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'denies access for admin without admin mode' do
        get api('/admin/data_management/project/1', admin)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with feature flag disabled' do
      before do
        Feature.disable(:geo_primary_verification_view)
      end

      it 'returns 404' do
        project = create(:project)

        get api("/admin/data_management/project/#{project.id}", admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
