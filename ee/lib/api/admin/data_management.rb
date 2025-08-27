# frozen_string_literal: true

module API
  module Admin
    class DataManagement < ::API::Base
      include PaginationParams
      include APIGuard

      feature_category :geo_replication
      urgency :low

      AVAILABLE_MODEL_NAMES = Gitlab::Geo::ModelMapper.available_model_names.freeze

      before do
        authenticated_as_admin!
        not_found! unless Feature.enabled?(:geo_primary_verification_view, current_user)
      end

      helpers do
        def verifiable?(model_class)
          return false unless ::Gitlab::Geo.enabled?
          return false unless model_class.respond_to?(:replicator_class)

          model_class.replicator_class.verification_enabled?
        end
      end

      resource :admin do
        resource :data_management do
          route_param :model_name, type: String, desc: 'The name of the model being managed' do
            # Example request:
            #   GET /admin/data_management/:model_name
            desc 'Get a list of model data' do
              summary 'Retrieve all records of the requested model'
              detail 'This feature is experimental.'
              success code: 200, model: Entities::Admin::Model
              failure [
                { code: 400, message: '400 Bad request' },
                { code: 401, message: '401 Unauthorized' },
                { code: 403, message: '403 Forbidden' },
                { code: 404, message: '404 Model Not Found' }
              ]
              is_array true
              tags %w[data_management]
            end
            params do
              use :pagination
              requires :model_name, type: String, values: AVAILABLE_MODEL_NAMES
            end

            get do
              model_class = Gitlab::Geo::ModelMapper.find_from_name(params[:model_name])
              not_found!(params[:model_name]) unless model_class

              relation = model_class.respond_to?(:with_state_details) ? model_class.with_state_details : model_class
              relation = relation.order_by_primary_key

              present paginate(relation.all, without_count: true), with: Entities::Admin::Model
            end

            route_param :id, type: Integer, desc: 'The ID of the model being requested' do
              # Example request:
              #   GET /admin/data_management/:model_name/:id
              desc 'Get data about a specific model' do
                summary 'Retrieve data about the requested model ID'
                detail 'This feature is experimental.'
                success code: 200, model: Entities::Admin::Model
                failure [
                  { code: 400, message: '400 Bad request' },
                  { code: 401, message: '401 Unauthorized' },
                  { code: 403, message: '403 Forbidden' },
                  { code: 404, message: '404 Model Not Found' }
                ]
                tags %w[data_management]
              end
              params do
                requires :model_name, type: String, values: AVAILABLE_MODEL_NAMES
                requires :id, type: Integer
              end

              get do
                model_class = Gitlab::Geo::ModelMapper.find_from_name(params[:model_name])
                not_found!(params[:model_name]) unless model_class

                model = model_class.find_by_primary_key(params[:id])
                not_found!(params[:id]) unless model

                present model, with: Entities::Admin::Model
              end

              # Example request:
              #   PUT /admin/data_management/:model_name/:id/checksum
              desc 'Recalculate the checksum of a specific model' do
                summary 'Recalculate the checksum of a specific model'
                detail 'This feature is experimental.'
                success code: 200, model: Entities::Admin::Model
                failure [
                  { code: 400, message: '400 Bad request' },
                  { code: 401, message: '401 Unauthorized' },
                  { code: 403, message: '403 Forbidden' },
                  { code: 404, message: '404 Model Not Found' }
                ]
                tags %w[data_management]
              end
              params do
                requires :model_name, type: String, values: AVAILABLE_MODEL_NAMES
                requires :id, type: Integer
              end

              put 'checksum' do
                bad_request!('Endpoint only available on primary site.') unless ::Gitlab::Geo.primary?

                model_class = Gitlab::Geo::ModelMapper.find_from_name(params[:model_name])
                not_found!(params[:model_name]) unless model_class
                bad_request!("#{model_class} is not a verifiable model.") unless verifiable?(model_class)

                model = model_class.find_by_primary_key(params[:id])
                not_found!(params[:id]) unless model

                event = model.replicator.verify
                bad_request!("Verifying #{params[:model_name]}/#{params[:id]} failed.") unless event

                present model, with: Entities::Admin::Model
              end
            end
          end
        end
      end
    end
  end
end
