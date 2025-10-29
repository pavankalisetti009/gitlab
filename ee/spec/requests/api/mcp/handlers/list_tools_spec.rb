# frozen_string_literal: true

require "spec_helper"

# rubocop:disable RSpec/SpecFilePathFormat -- JSON-RPC has single path for method invocation
RSpec.describe API::Mcp, 'List tools request', feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:access_token) { create(:oauth_access_token, user: user, scopes: [:mcp]) }

  before do
    stub_application_setting(instance_level_ai_beta_features_enabled: true)
  end

  describe 'POST /mcp with tools/list method' do
    let(:params) do
      {
        jsonrpc: '2.0',
        method: 'tools/list',
        id: '1'
      }
    end

    def post_list_tools
      post api('/mcp', user, oauth_access_token: access_token), params: params
    end

    it 'returns success' do
      post_list_tools

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['jsonrpc']).to eq(params[:jsonrpc])
      expect(json_response['id']).to eq(params[:id])
      expect(json_response.keys).to include('result')
    end

    it 'returns tools' do
      post_list_tools

      expect(json_response['result']['tools']).to contain_exactly(
        {
          "name" => "get_pipeline_jobs",
          "description" => "Get pipeline jobs",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "string",
                "description" => "The project ID or URL-encoded path"
              },
              "pipeline_id" => {
                "type" => "integer",
                "description" => "The pipeline ID"
              },
              "per_page" => {
                "type" => "integer",
                "description" => "Number of items per page"
              },
              "page" => {
                "type" => "integer",
                "description" => "Current page number"
              }
            },
            "required" => %w[id pipeline_id],
            "additionalProperties" => false
          }
        },
        {
          "name" => "get_issue",
          "description" => "Get a single project issue",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "string",
                "description" => "The ID or URL-encoded path of the project"
              },
              "issue_iid" => {
                "type" => "integer",
                "description" => "The internal ID of a project issue"
              }
            },
            "required" => %w[id issue_iid],
            "additionalProperties" => false
          }
        },
        {
          "name" => "create_issue",
          "description" => "Create a new project issue",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "string",
                "description" => "The ID or URL-encoded path of the project"
              },
              "title" => {
                "type" => "string",
                "description" => "The title of an issue"
              },
              "description" => {
                "type" => "string",
                "description" => "The description of an issue"
              },
              "assignee_ids" => {
                "type" => "array",
                "description" => "The array of user IDs to assign issue"
              },
              "milestone_id" => {
                "type" => "integer",
                "description" => "The ID of a milestone to assign issue"
              },
              "labels" => {
                "type" => "string",
                "description" => "Comma-separated list of label names"
              },
              "confidential" => {
                "type" => "boolean",
                "description" => "Boolean parameter if the issue should be confidential"
              },
              "epic_id" => {
                "type" => "integer",
                "description" => "The ID of an epic to associate the issue with"
              }
            },
            "required" => %w[id title],
            "additionalProperties" => false
          }
        },
        {
          "name" => "create_merge_request",
          "description" => "Create merge request",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "string",
                "description" => "The ID or URL-encoded path of the project."
              },
              "title" => {
                "type" => "string",
                "description" => "The title of the merge request."
              },
              "source_branch" => {
                "type" => "string",
                "description" => "The source branch."
              },
              "target_branch" => {
                "type" => "string",
                "description" => "The target branch."
              },
              "target_project_id" => {
                "type" => "integer",
                "description" => "The target project of the merge request defaults to the :id of the project."
              }
            },
            "required" => %w[id title source_branch target_branch],
            "additionalProperties" => false
          }
        },
        {
          "name" => "get_merge_request",
          "description" => "Get single merge request",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "string",
                "description" => "The ID or URL-encoded path of the project."
              },
              "merge_request_iid" => {
                "type" => "integer",
                "description" => "The internal ID of the merge request."
              }
            },
            "required" => %w[id merge_request_iid],
            "additionalProperties" => false
          }
        },
        {
          "name" => "get_merge_request_commits",
          "description" => "Get single merge request commits",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "string",
                "description" => "The ID or URL-encoded path of the project."
              },
              "merge_request_iid" => {
                "type" => "integer",
                "description" => "The internal ID of the merge request."
              },
              "per_page" => {
                "type" => "integer",
                "description" => "Number of items per page"
              },
              "page" => {
                "type" => "integer",
                "description" => "Current page number"
              }
            },
            "required" => %w[id merge_request_iid],
            "additionalProperties" => false
          }
        },
        {
          "name" => "get_merge_request_diffs",
          "description" => "Get the merge request diffs",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "string",
                "description" => "The ID or URL-encoded path of the project."
              },
              "merge_request_iid" => {
                "type" => "integer",
                "description" => "The internal ID of the merge request."
              },
              "per_page" => {
                "type" => "integer",
                "description" => "Number of items per page"
              },
              "page" => {
                "type" => "integer",
                "description" => "Current page number"
              }
            },
            "required" => %w[id merge_request_iid],
            "additionalProperties" => false
          }
        },
        {
          "name" => "get_merge_request_pipelines",
          "description" => "Get single merge request pipelines",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "string",
                "description" => "The ID or URL-encoded path of the project."
              },
              "merge_request_iid" => {
                "type" => "integer",
                "description" => "The internal ID of the merge request."
              }
            },
            "required" => %w[id merge_request_iid],
            "additionalProperties" => false
          }
        },
        {
          "name" => "gitlab_search",
          "description" => "Search on GitLab",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "scope" => {
                "type" => "string",
                "description" => "The scope of the search"
              },
              "search" => {
                "type" => "string",
                "description" => "The expression it should be searched for"
              },
              "state" => {
                "type" => "string",
                "description" => "Filter results by state"
              },
              "confidential" => {
                "type" => "boolean",
                "description" => "Filter results by confidentiality"
              },
              "page" => {
                "type" => "integer",
                "description" => "Current page number"
              },
              "per_page" => {
                "type" => "integer",
                "description" => "Number of items per page"
              },
              "fields" => {
                "type" => "string",
                "description" => "Array of fields you wish to search"
              }
            },
            "required" => %w[scope search],
            "additionalProperties" => false
          }
        },
        {
          "name" => "get_mcp_server_version",
          "description" => "Get the current version of MCP server.",
          "inputSchema" => {
            "type" => "object",
            "properties" => {},
            "required" => []
          }
        }
      )
    end

    context 'when semantic code search is available' do
      before do
        # We have to use `allow_any_instance_of` since this tool is initialized
        # *on class definition time* in EE::Mcp::Tools::Manager
        allow_any_instance_of(Mcp::Tools::SearchCodebaseService).to receive(:available?).and_return(true) # rubocop: disable RSpec/AnyInstanceOf -- see explanation above
      end

      it 'returns the semantic_code_search in the tools list' do
        post_list_tools

        tools = json_response['result']['tools']
        semantic_code_search = tools.find { |tool| tool['name'] == 'semantic_code_search' }

        expect(semantic_code_search).not_to be_nil

        tool_description = <<~DESC.strip
          Performs semantic code search across project files using vector similarity.

          Returns ranked code snippets with file paths and content matches based on natural language queries.

          Use this tool for questions about a project's codebase.
          For example: "how something works" or "code that does X", or finding specific implementations.

          This tool supports directory scoping and configurable result limits for targeted code discovery and analysis.
        DESC

        expect(semantic_code_search).to eq(
          {
            "name" => "semantic_code_search",
            "description" => tool_description,
            "inputSchema" => {
              "type" => "object",
              "properties" => {
                "semantic_query" => {
                  "type" => "string",
                  "minLength" => 1,
                  "maxLength" => 1000,
                  "description" => "" \
                    "A brief natural language query about the code you want to find in the project " \
                    "(e.g.: 'authentication middleware', 'database connection logic', or 'API error handling')."
                },
                "project_id" => {
                  "type" => "string",
                  "description" => "Either a project id or project path."
                },
                "directory_path" => {
                  "type" => "string",
                  "minLength" => 1,
                  "maxLength" => 100,
                  "description" => "Optional directory path to scope the search (e.g., \"app/services/\")."
                },
                "knn" => {
                  "type" => "integer",
                  "default" => 64,
                  "minimum" => 1,
                  "maximum" => 100,
                  "description" => "" \
                    "Number of nearest neighbors used internally. " \
                    "This controls search precision vs. speed - " \
                    "higher values find more diverse results but take longer."
                },
                "limit" => {
                  "type" => "integer",
                  "default" => 20,
                  "minimum" => 1,
                  "maximum" => 100,
                  "description" => "Maximum number of results to return."
                }
              },
              "required" => %w[semantic_query project_id],
              "additionalProperties" => false
            }
          }
        )
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
