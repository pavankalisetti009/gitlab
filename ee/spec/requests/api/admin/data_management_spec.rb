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
            expect(json_response.first).to include('record_identifier' => expected_model.id,
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
              first_page_ids = json_response.pluck('record_identifier')

              get api("/admin/data_management/project?per_page=3&page=2", admin, admin_mode: true)
              second_page_ids = json_response.pluck('record_identifier')

              # Verify ordering is maintained across pages
              expect(first_page_ids).to eq(first_page_ids.sort)
              expect(second_page_ids).to eq(second_page_ids.sort)
              expect(first_page_ids.last).to be < second_page_ids.first
            end

            context 'with composite IDs' do
              let_it_be(:list) { create_list(:virtual_registries_packages_maven_cache_entry, 9) }
              # We're using this Entry model because it will be the first model with composite PKs supported by Geo.
              # The model isn't Geo-ready yet, so we need to mock its interface in this test to simulate its future
              # implementation.
              let_it_be(:orderable_klass) do
                Class.new(list.first.class) do
                  include Orderable
                end
              end

              before do
                # The VirtualRegistries::Packages::Maven::Cache::Entry model is not in the allowed list yet.
                # This is why we need to force the ModelMapper to return the stubbed class instead of the model
                # passed as parameters.
                allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name).with('project').and_return(orderable_klass)
              end

              it 'paginates results' do
                get api("/admin/data_management/project?per_page=5", admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.size).to eq(5)
                expect(response.headers['X-Next-Page']).to eq('2')
                expect(response.headers['X-Page']).to eq('1')
                expect(response.headers['X-Per-Page']).to eq('5')

                get api("/admin/data_management/project?per_page=5&page=2", admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.size).to eq(4) # Remaining 4 records
                expect(response.headers['X-Page']).to eq('2')
                expect(response.headers['X-Next-Page']).to be_empty
              end
            end
          end

          context 'with filtering based on ids' do
            context 'with integer ids' do
              let_it_be(:list) { create_list(:project, 3) }

              it 'filters passed ids' do
                get api("/admin/data_management/project?identifiers[]=#{list.first.id}&identifiers[]=#{list.last.id}",
                  admin,
                  admin_mode: true)

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.pluck('record_identifier')).to eq([list.first.id, list.last.id])
                expect(json_response.size).to eq(2)
              end
            end

            context 'with composite ids' do
              let_it_be(:list) { create_list(:virtual_registries_packages_maven_cache_entry, 3) }
              # We're using this Entry model because it will be the first model with composite PKs supported by Geo.
              # The model isn't Geo-ready yet, so we need to mock its interface in this test to simulate its future
              # implementation.
              let_it_be(:orderable_klass) do
                Class.new(list.first.class) do
                  include Orderable
                end
              end

              let_it_be(:ids_list) do
                list.map do |model|
                  Base64.urlsafe_encode64(orderable_klass
                                            .primary_key
                                            .map { |field| model.read_attribute_before_type_cast(field) }
                                            .join(' '))
                end
              end

              before do
                # The VirtualRegistries::Packages::Maven::Cache::Entry model is not in the allowed list yet.
                # This is why we need to force the ModelMapper to return the stubbed class instead of the model
                # passed as parameters.
                allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name).with('project').and_return(orderable_klass)
              end

              it 'filters passed ids' do
                get api("/admin/data_management/project?identifiers[]=#{ids_list.first}&identifiers[]=#{ids_list.last}",
                  admin,
                  admin_mode: true)

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.pluck('record_identifier')).to eq([ids_list.first, ids_list.last])
                expect(json_response.size).to eq(2)
              end
            end

            context 'with invalid ids' do
              it 'returns 400 with mixed ids' do
                fake_b64 = Base64.urlsafe_encode64('1 2 3')

                get api("/admin/data_management/project?identifiers[]=1&identifiers[]=#{fake_b64}",
                  admin,
                  admin_mode: true)

                expect(response).to have_gitlab_http_status(:bad_request)
                expect(json_response['message']).to include('invalid base64')
              end

              it 'returns 400 with invalid composite keys' do
                fake_ids = [Base64.urlsafe_encode64('1 2 3'), Base64.urlsafe_encode64('4-5-6')]
                url = "/admin/data_management/project?identifiers[]=#{fake_ids.first}&identifiers[]=#{fake_ids.last}"

                get api(url, admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:bad_request)
                expect(json_response['message']).to include('Invalid composite key format')
              end

              it 'does not filter with empty ids' do
                list = create_list(:project, 3)

                get api("/admin/data_management/project?identifiers[]=", admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.pluck('record_identifier')).to match_array(list.map(&:id))
                expect(json_response.size).to eq(3)
              end
            end
          end

          context 'with filtering based on status' do
            context 'with valid status' do
              let_it_be(:node) { create(:geo_node) }
              let(:succeeded_record) { build(:upload, :verification_succeeded) }
              let(:failed_record) { build(:upload, :verification_failed) }
              let(:pending_record) { build_record_for_given_state(:verification_pending) }
              let(:started_record) { build_record_for_given_state(:verification_started) }
              let(:disabled_record) { build_record_for_given_state(:verification_disabled) }

              def build_record_for_given_state(state)
                build(:upload, verification_state: Upload.verification_state_value(state))
              end

              before do
                stub_current_geo_node(node)
                stub_primary_site

                succeeded_record.save!
                failed_record.save!
                pending_record.save!
                started_record.save!
                disabled_record.save!
              end

              where(status: %w[pending started succeeded failed disabled])
              with_them do
                it 'returns matching object data' do
                  get api("/admin/data_management/upload?checksum_state=#{status}", admin, admin_mode: true)

                  expect(response).to have_gitlab_http_status(:ok)
                  expect(json_response.first).to include('record_identifier' => send(:"#{status}_record").id)
                  expect(json_response.size).to eq(1)
                end
              end
            end

            context 'with invalid status' do
              it 'returns 400' do
                get api('/admin/data_management/project?checksum_state=invalid', admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:bad_request)
              end
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
            response_ids = json_response.pluck('record_identifier')
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

  describe 'PUT /admin/data_management/:model_name/checksum' do
    context 'with feature flag enabled' do
      let_it_be(:node) { create(:geo_node) }
      let_it_be(:api_path) { "/admin/data_management/merge_request_diff/checksum" }

      before do
        stub_current_geo_node(node)
        stub_primary_site
      end

      context 'when authenticated as admin' do
        context 'when not on primary site' do
          before do
            allow(Gitlab::Geo).to receive(:primary?).and_return(false)
          end

          it 'returns 400 bad request' do
            put api(api_path, admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq('400 Bad request - Endpoint only available on primary site.')
          end
        end

        context 'with valid model name' do
          it 'returns service result' do
            expect(::Geo::BulkPrimaryVerificationService).to receive(:new).with('merge_request_diff').and_call_original

            put api(api_path, admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include('status' => 'success')
          end

          context 'when service returns an error' do
            before do
              allow(::Geo::BulkPrimaryVerificationService).to receive_message_chain(:new, :async_execute)
                                                                .and_return(ServiceResponse.error(message: 'Error'))
            end

            it 'returns error message' do
              put api(api_path, admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).to include('status' => 'error')
            end
          end
        end

        context 'with invalid model names' do
          # Edge cases - invalid inputs
          it 'returns 400 for non-existent model name' do
            put api('/admin/data_management/non_existent_model/checksum', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end

          it 'returns 404 for empty model name' do
            put api('/admin/data_management/checksum', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'with URL encoding' do
          # Edge cases - URL encoded characters
          it 'handles URL encoded model names' do
            put api('/admin/data_management/lfs%5Fobject/checksum', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'handles URL encoded special characters' do
            put api('/admin/data_management/lfs%40object/checksum', admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context 'when not authenticated as admin' do
        # Security boundary tests
        it 'denies access for regular users' do
          put api(api_path, user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'denies access for unauthenticated requests' do
          put api(api_path)

          expect(response).to have_gitlab_http_status(:unauthorized)
        end

        it 'denies access for admin without admin mode' do
          put api(api_path, admin)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'with feature flag disabled' do
      before do
        Feature.disable(:geo_primary_verification_view)
      end

      it 'returns 404' do
        put api("/admin/data_management/terraform_state_version/checksum", admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /admin/data_management/:model_name/:record_identifier' do
    context 'with feature flag enabled' do
      context 'with valid model name' do
        let(:expected_model) { create(:snippet_repository) }

        context 'with valid integer id' do
          it 'returns matching object data' do
            get api("/admin/data_management/snippet_repository/#{expected_model.id}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include('record_identifier' => expected_model.id,
              'model_class' => expected_model.class.name)
          end
        end

        context 'with valid base64 id' do
          let_it_be(:model) { create(:virtual_registries_packages_maven_cache_entry) }
          # We're using this Entry model because it will be the first model with composite PKs supported by Geo.
          # The model isn't Geo-ready yet, so we need to mock its interface in this test to simulate its future
          # implementation.
          let_it_be(:stubbed_class) do
            Class.new(model.class) do
              include Geo::HasReplicator
            end
          end

          let_it_be(:base64_id) do
            pks = model.class.primary_key
            ids = pks.map { |field| model.read_attribute_before_type_cast(field).to_s }
            Base64.urlsafe_encode64(ids.join(' '))
          end

          before do
            # The VirtualRegistries::Packages::Maven::Cache::Entry model is not in the allowed list.
            # This is why the url matches`project` but I force the ModelMapper to return the stubbed class instead.
            allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name).with('project').and_return(stubbed_class)
          end

          it 'returns matching object data' do
            get api("/admin/data_management/project/#{base64_id}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include('record_identifier' => base64_id)
          end
        end

        context 'with invalid id' do
          it 'returns 404 when ID does not exist' do
            get api("/admin/data_management/snippet_repository/#{non_existing_record_id}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:not_found)
          end

          it 'returns 400 when ID is alphanumeric containing valid ID' do
            get api("/admin/data_management/snippet_repository/rand#{expected_model.id}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'with invalid base64 id' do
          let(:model) { create(:virtual_registries_packages_maven_cache_entry) }
          let(:base64_id) do
            expected_id = model.class.primary_key.map { |field| model[field.to_sym].to_s }
            Base64.urlsafe_encode64(expected_id.join('-'))
          end

          before do
            # The VirtualRegistries::Packages::Maven::Cache::Entry model is not in the allowed list.
            # This is why the url matches`project` but I force the ModelMapper to return
            # the MavenCacheEntry double instead of the normally expected `Project`.
            allow(Gitlab::Geo::ModelMapper).to receive(:find_from_name).with('project').and_return(model.class)
          end

          it 'returns 400 when base64 does not contain spaces' do
            get api("/admin/data_management/project/#{base64_id}", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response).to include('message' => '400 Bad request - Invalid composite key format')
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
            expect(json_response).to include('record_identifier' => expected_record.id,
              'model_class' => expected_record.class.name)
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

  describe 'PUT /admin/data_management/:model_name/:record_identifier/checksum' do
    let_it_be(:expected_model) { create(:snippet_repository) }
    let_it_be(:api_path) { "/admin/data_management/snippet_repository/#{expected_model.id}/checksum" }
    let_it_be(:node) { create(:geo_node) }

    before do
      stub_current_geo_node(node)
      stub_primary_site
    end

    context 'with feature flag disabled' do
      before do
        Feature.disable(:geo_primary_verification_view)
      end

      it 'returns 404' do
        put api(api_path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with feature flag enabled' do
      context 'when not on primary site' do
        before do
          allow(Gitlab::Geo).to receive(:primary?).and_return(false)
        end

        it 'returns 400 bad request' do
          put api(api_path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('400 Bad request - Endpoint only available on primary site.')
        end
      end

      context 'when user is not authenticated' do
        it 'returns 401 unauthorized' do
          put api(api_path)

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'when user is not an admin' do
        it 'returns 403 forbidden' do
          put api(api_path, user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with valid model name' do
        context 'with valid id' do
          it 'returns successful message' do
            put api(api_path, admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include('record_identifier' => expected_model.id,
              'model_class' => expected_model.class.name)
          end

          context 'when model is not replicable' do
            before do
              allow(expected_model.class).to receive(:respond_to?).with(:replicator_class).and_return(false)
            end

            it 'returns 400 bad request' do
              put api(api_path, admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['message']).to include('is not a verifiable model')
            end
          end

          context 'when model is not verifiable' do
            before do
              allow(expected_model.class.replicator_class).to receive(:verification_enabled?).and_return(false)
            end

            it 'returns 400 bad request' do
              put api(api_path, admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['message']).to include('is not a verifiable model')
            end
          end

          context 'when verification fails' do
            before do
              allow_next_instance_of(expected_model.replicator.class) do |replicator|
                allow(replicator).to receive(:verify).and_return(nil)
              end
            end

            it 'returns 400 bad request' do
              put api(api_path, admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['message']).to include("Verifying snippet_repository/#{expected_model.id} failed")
            end
          end
        end
      end

      context 'with all available replicable models' do
        where(model_classes: Gitlab::Geo::Replicator.subclasses.map(&:model))

        with_them do
          let(:model_name) { Gitlab::Geo::ModelMapper.convert_to_name(model_classes) }
          let(:expected_record) { create(factory_name(model_classes)) } # rubocop:disable Rails/SaveBang -- factory

          it 'handles all known replicable model names' do
            put api("/admin/data_management/#{model_name}/#{expected_record.id}/checksum", admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include('record_identifier' => expected_record.id,
              'model_class' => expected_record.class.name)
          end
        end
      end
    end
  end
end
