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

        def find_model_from_record_identifier(identifier, model_class)
          primary_key_value = if identifier.is_a?(Integer)
                                identifier
                              else
                                decoded_string = Base64.urlsafe_decode64(identifier)
                                bad_request!('Invalid composite key format') unless decoded_string.include?(' ')

                                decoded_string.split(' ')
                              end

          model_class.find_by_primary_key(primary_key_value)
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

            route_param :record_identifier,
              types: [Integer, String],
              desc: 'The identifier of the model being requested' do
              # Example request:
              #   GET /admin/data_management/:model_name/:record_identifier
              desc 'Get data about a specific model' do
                summary 'Retrieve data about the requested model record identifier'
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
                requires :record_identifier, types: [Integer, String]
              end

              get do
                model_class = Gitlab::Geo::ModelMapper.find_from_name(params[:model_name])
                not_found!(params[:model_name]) unless model_class

                model = find_model_from_record_identifier(params[:record_identifier], model_class)
                not_found!(params[:record_identifier]) unless model

                present model, with: Entities::Admin::Model
              rescue ArgumentError, TypeError => e
                bad_request!(e)
              end

              # Example request:
              #   PUT /admin/data_management/:model_name/:record_identifier/checksum
              desc 'Recalculate the checksum of a specific model' do
                summary 'Recalculate the checksum of the requested model record identifier'
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
                requires :record_identifier, type: Integer
              end

              put 'checksum' do
                bad_request!('Endpoint only available on primary site.') unless ::Gitlab::Geo.primary?

                model_class = Gitlab::Geo::ModelMapper.find_from_name(params[:model_name])
                not_found!(params[:model_name]) unless model_class
                bad_request!("#{model_class} is not a verifiable model.") unless verifiable?(model_class)

                model = find_model_from_record_identifier(params[:record_identifier], model_class)
                not_found!(params[:record_identifier]) unless model

                event = model.replicator.verify
                bad_request!("Verifying #{params[:model_name]}/#{params[:record_identifier]} failed.") unless event

                present model, with: Entities::Admin::Model
              end
            end
          end
        end
      end
    end
  end
end
