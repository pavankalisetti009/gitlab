# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      # This API is intended to be consumed by a running Duo Workflow using
      # the ai_workflows scope token. These are requests coming from Duo Workflow
      # Service and Duo Workflow Executor. We should not add any more requests to
      # this API than needed by those 2 components. Otherwise add to
      # `API::Ai::DuoWorkflows::Workflows`.
      class WorkflowsInternal < ::API::Base
        include PaginationParams
        include APIGuard

        COMPRESS_LEVEL = 6 # Fast and good zlib compression

        helpers ::API::Helpers::DuoWorkflowHelpers

        allow_access_with_scope :ai_workflows

        feature_category :duo_agent_platform

        before { authenticate! }

        helpers do
          def find_workflow!(id)
            workflow = ::Ai::DuoWorkflows::Workflow.for_user_with_id!(human_user.id, id)
            return workflow if current_user.can?(:read_duo_workflow, workflow)

            forbidden!
          end

          def human_user
            current_user
          end

          def find_event!(workflow, id)
            workflow.events.find(id)
          end

          def render_response(response)
            if response.success?
              status :ok
              response.payload
            else
              status_code = error_status_for(response.reason)
              render_api_error!(response.message, status_code)
            end
          end

          def error_status_for(reason)
            {
              not_found: :not_found,
              unauthorized: :unauthorized,
              invalid_token_ownership: :forbidden,
              insufficient_token_scope: :forbidden,
              failed_to_revoke: :unprocessable_entity
            }.fetch(reason, :bad_request)
          end

          def compress_checkpoint(checkpoint_data)
            Base64.strict_encode64(Zlib::Deflate.deflate(checkpoint_data.to_json, COMPRESS_LEVEL))
          end

          def uncompress_checkpoint(compressed_data)
            ::Gitlab::Json.parse(Zlib::Inflate.inflate(Base64.strict_decode64(compressed_data)))
          rescue ArgumentError, Zlib::Error, JSON::ParserError => e
            bad_request!("Invalid compressed checkpoint data: #{e.message}")
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            desc 'Revoke ai_workflows token' do
              success code: 200
              failure [
                { code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Forbidden' },
                { code: 422, message: 'Unprocessable Entity' }
              ]
            end
            params do
              requires :token, type: String, desc: 'The access token to revoke'
            end
            post :revoke_token do
              service = ::Ai::DuoWorkflows::RevokeTokenService.new(
                token: params[:token],
                current_user: current_user
              )

              render_response(service.execute)
            end

            namespace :workflows do
              namespace '/:id' do
                params do
                  requires :id, type: Integer, desc: 'The ID of the workflow', documentation: { example: 1 }
                end
                get do
                  workflow = find_workflow!(params[:id])
                  push_ai_gateway_headers

                  present workflow, with: ::API::Entities::Ai::DuoWorkflows::Workflow
                end

                desc 'Updates the workflow status' do
                  success code: 200
                end
                params do
                  requires :id, type: Integer, desc: 'The ID of the workflow', documentation: { example: 1 }
                  requires :status_event, type: String, desc: 'The status event',
                    documentation: { example: 'finish' }
                end
                patch do
                  workflow = find_workflow!(params[:id])
                  forbidden! unless current_user.can?(:update_duo_workflow, workflow)

                  service = ::Ai::DuoWorkflows::UpdateWorkflowStatusService.new(
                    workflow: workflow,
                    status_event: params[:status_event],
                    current_user: current_user
                  )

                  render_response(service.execute)
                end

                namespace :checkpoints do
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :thread_ts, type: String, desc: 'The thread ts'
                    optional :parent_ts, type: String, desc: 'The parent ts'
                    optional :checkpoint, type: Hash, desc: "Checkpoint content"
                    optional :compressed_checkpoint, type: String,
                      desc: "Checkpoint content zlib compressed and base64 encoded"
                    requires :metadata, type: Hash, desc: "Checkpoint metadata"
                  end
                  post do
                    workflow = find_workflow!(params[:id])
                    checkpoint = if params[:checkpoint].present?
                                   params[:checkpoint]
                                 elsif params[:compressed_checkpoint].present?
                                   uncompress_checkpoint(params[:compressed_checkpoint])
                                 end

                    bad_request!('Either checkpoint or compressed_checkpoint must be provided') unless checkpoint

                    checkpoint_params = declared_params(include_missing: false)
                                          .except(:id)
                                          .merge(checkpoint: checkpoint)

                    service = ::Ai::DuoWorkflows::CreateCheckpointService.new(
                      workflow: workflow, params: checkpoint_params)
                    result = service.execute

                    bad_request!(result[:message]) if result[:status] == :error

                    present result[:checkpoint], with: ::API::Entities::Ai::DuoWorkflows::BasicCheckpoint
                  end

                  params do
                    optional :accept_compressed, type: Boolean, default: false, desc: "Return compressed checkpoints"
                  end
                  get do
                    workflow = find_workflow!(params[:id])
                    checkpoints = workflow.checkpoints.ordered_with_writes
                    checkpoints = paginate(checkpoints)
                    if params[:accept_compressed]
                      checkpoints.each { |cp| cp.compressed_checkpoint = compress_checkpoint(cp.checkpoint) }
                    end

                    present checkpoints, with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
                  end

                  namespace '/:checkpoint_id' do
                    params do
                      requires :checkpoint_id, type: Integer, desc: 'The ID of the checkpoint',
                        documentation: { example: 1 }
                      optional :accept_compressed, type: Boolean, default: false, desc: "Return compressed checkpoint"
                    end
                    get do
                      workflow = find_workflow!(params[:id])
                      checkpoint = workflow.checkpoints.with_checkpoint_writes.find_by_id(params[:checkpoint_id])

                      not_found! unless checkpoint

                      if params[:accept_compressed]
                        checkpoint.compressed_checkpoint = compress_checkpoint(checkpoint.checkpoint)
                      end

                      present checkpoint, with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
                    end
                  end
                end

                namespace :checkpoint_writes_batch do
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :thread_ts, type: String, desc: 'The thread ts'
                    requires :checkpoint_writes, type: Array, allow_blank: false, desc: 'List of checkpoint writes' do
                      requires :task, type: String, desc: 'The task id'
                      requires :idx, type: Integer, desc: 'The index of checkpoint write'
                      requires :channel, type: String, desc: 'The channel'
                      requires :write_type, type: String, desc: 'The type of data'
                      requires :data, type: String, desc: 'The checkpoint write data'
                    end
                  end
                  post do
                    workflow = find_workflow!(params[:id])
                    result = ::Ai::DuoWorkflows::CreateCheckpointWriteBatchService.new(
                      workflow: workflow,
                      params: declared_params(include_missing: false).except(:id)
                    ).execute

                    bad_request!(result.message) if result.error?

                    status :ok
                  end
                end

                namespace :events do
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :event_type, type: String, values: ::Ai::DuoWorkflows::Event.event_types.keys,
                      desc: 'The type of event'
                    requires :message, type: String, desc: "Message from the human"
                    optional :correlation_id, type: String, desc: "Correlation ID for tracking events",
                      regexp: ::Ai::DuoWorkflows::Event::UUID_REGEXP
                  end
                  post do
                    workflow = find_workflow!(params[:id])
                    event_params = declared_params(include_missing: false).except(:id)
                    service = ::Ai::DuoWorkflows::CreateEventService.new(
                      workflow: workflow,
                      params: event_params.merge(event_status: :queued)
                    )
                    result = service.execute

                    bad_request!(result[:message]) if result[:status] == :error

                    present result[:event], with: ::API::Entities::Ai::DuoWorkflows::Event
                  end

                  get do
                    workflow = find_workflow!(params[:id])
                    events = workflow.events.queued
                    present paginate(events), with: ::API::Entities::Ai::DuoWorkflows::Event
                  end

                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :event_id, type: Integer, desc: 'The ID of the event'
                    requires :event_status, type: String, values: %w[queued delivered], desc: 'The status of the event'
                  end
                  put '/:event_id' do
                    workflow = find_workflow!(params[:id])
                    event = find_event!(workflow, params[:event_id])
                    event_params = declared_params(include_missing: false).except(:id, :event_id)
                    service = ::Ai::DuoWorkflows::UpdateEventService.new(
                      event: event,
                      params: event_params
                    )
                    result = service.execute

                    bad_request!(result[:message]) if result[:status] == :error

                    present result[:event], with: ::API::Entities::Ai::DuoWorkflows::Event
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
