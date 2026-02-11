# frozen_string_literal: true

require "spec_helper"

# rubocop:disable RSpec/SpecFilePathFormat -- JSON-RPC has single path for method invocation
RSpec.describe API::Mcp, 'List tools request', feature_category: :mcp_server do
  let_it_be(:user) { create(:user) }
  let_it_be(:access_token) { create(:oauth_access_token, user: user, scopes: [:mcp]) }

  before do
    stub_application_setting(instance_level_ai_beta_features_enabled: true, duo_features_enabled: true)
    stub_ee_application_setting(elasticsearch_search: true)
    allow(::Search::Zoekt).to receive(:enabled?).and_return(true)

    # Stub semantic code search availability to avoid ActiveContext infrastructure dependency
    # We have to use `allow_any_instance_of` since this tool is initialized
    # *on class definition time* in EE::Mcp::Tools::Manager
    allow_any_instance_of(Mcp::Tools::SemanticCodeSearchService).to receive(:available?).and_return(false) # rubocop:disable RSpec/AnyInstanceOf -- tool is initialized at class definition time
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

    # rubocop:disable Layout/LineLength -- disabling to make updating the test easier by not having to fix line length
    it 'returns tools' do
      post_list_tools

      expected_icons = [Mcp::Tools::IconConfig.gitlab_icons.first.stringify_keys]

      expect(json_response['result']['tools']).to contain_exactly(
        {
          "name" => "get_pipeline_jobs",
          "description" => "Get pipeline jobs",
          "icons" => expected_icons,
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
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "get_issue",
          "description" => "Get a single project issue",
          "icons" => expected_icons,
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
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "create_issue",
          "description" => "Create a new project issue",
          "icons" => expected_icons,
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
                "items" => {
                  "type" => "integer"
                },
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
          "icons" => expected_icons,
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "id" => { "type" => "string", "description" => "The ID or URL-encoded path of the project." },
              "title" => { "type" => "string", "description" => "The title of the merge request." },
              "source_branch" => { "type" => "string", "description" => "The source branch." },
              "target_branch" => { "type" => "string", "description" => "The target branch." },
              "target_project_id" => {
                "type" => "integer",
                "description" => "The target project of the merge request defaults to the :id of the project."
              },
              "assignee_ids" => {
                "type" => "array",
                "items" => { "type" => "integer" },
                "description" => "The IDs of the users to assign the merge request to, as a comma-separated list. Set to 0 or provide an empty value to unassign all assignees."
              },
              "reviewer_ids" => {
                "type" => "array",
                "items" => { "type" => "integer" },
                "description" => "The IDs of the users to review the merge request, as a comma-separated list. Set to 0 or provide an empty value to unassign all reviewers."
              },
              "description" => {
                "type" => "string",
                "description" => "Description of the merge request. Limited to 1,048,576 characters."
              },
              "labels" => {
                "type" => "string",
                "description" => "Comma-separated label names for a merge request. Set to an empty string to unassign all labels."
              },
              "milestone_id" => {
                "type" => "integer",
                "description" => "The global ID of a milestone to assign the merge request to."
              }
            },
            "required" => %w[id title source_branch target_branch],
            "additionalProperties" => false
          }
        },
        {
          "name" => "get_merge_request",
          "description" => "Get single merge request",
          "icons" => expected_icons,
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
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "get_merge_request_commits",
          "description" => "Get single merge request commits",
          "icons" => expected_icons,
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
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "get_merge_request_diffs",
          "description" => "Get the merge request diffs",
          "icons" => expected_icons,
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
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "get_merge_request_pipelines",
          "description" => "Get single merge request pipelines",
          "icons" => expected_icons,
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
          },
          "annotations" => { "readOnlyHint" => true }
        },
        { "name" => "search",
          "icons" => expected_icons,
          "description" => "" \
            "Search across GitLab with automatic selection of the best available search method.\n\n" \
            "**Capabilities:** basic (keywords, file filters), advanced (boolean operators), exact code (exact match, regex, symbols)\n\n**Syntax Examples:**\n" \
            "- Basic: \"bug fix\", \"filename:*.rb\", \"extension:js\"\n" \
            "- Advanced: \"bug AND critical\", \"display | banner\", \"#23456\"\n" \
            "- Exact code: \"class User\", \"foo lang:ruby\", \"sym:initialize\"",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "scope" => {
                "type" => "string",
                "description" =>
                  "Specify the type of content to search for. Available content types vary by search context:\n\n- GitLab instance: projects, milestones, issues, merge_requests, snippet_titles, users, blobs, commits, epics, notes, wiki_blobs\n- Group: projects, milestones, issues, merge_requests, snippet_titles, users, blobs, commits, epics, notes, wiki_blobs\n- Project: projects, milestones, issues, merge_requests, snippet_titles, users, blobs, wiki_blobs, commits, notes\n\nExamples:\n- Use \"issues\" to search for issues\n- Use \"merge_requests\" to search for merge requests\n- Use \"blobs\" to search code files\n- Use \"notes\" to search comments across different content\n- Use \"commits\" to search commit messages"
              },
              "search" => {
                "type" => "string",
                "description" => "The term to search for"
              },
              "group_id" => {
                "type" => "string",
                "description" => "Provide to search within a group. The ID or URL-encoded path of the group"
              },
              "project_id" => {
                "type" => "string",
                "description" => "Provide to search within a project. The ID or URL-encoded path of the project"
              },
              "state" => {
                "type" => "string",
                "description" => "Filter results by state. Available states:\n- Issues: opened, closed\n- Merge requests: opened, closed, merged, locked)\n\nOnly applies to issues and merge_requests scopes."
              },
              "confidential" => {
                "type" => "boolean",
                "description" => "Filter results by confidentiality. Available for issues scope; other scopes are ignored."
              },
              "regex" => {
                "type" => "boolean",
                "description" => "Performs a regex code search. Available for blobs scope; other scopes are ignored."
              },
              "fields" => {
                "type" => "array", "items" => { "type" => "string" },
                "description" => "Specify which fields to search within. Currently supported:\n- Allowed values: title only\n- Applicable scopes: issues, merge_requests"
              },
              "order_by" => {
                "type" => "string",
                "description" => "Specify how to order search results.\n- Allowed values: created_at only\n- Default behavior:\n  * Basic search: sorted by created_at descending\n  * Advanced search: sorted by relevance"
              },
              "sort" => {
                "type" => "string",
                "description" => "Specify the sort direction for results. Works with order_by parameter\n- Allowed values: asc, desc\n- Default: desc"
              },
              "per_page" => {
                "type" => "integer",
                "description" => "Number of items to list per page. (default: 20)",
                "minimum" => 1
              },
              "page" => {
                "type" => "integer",
                "description" => "Page number to retrieve. (default: 1)",
                "minimum" => 1
              }
            },
            "required" => %w[scope search],
            "additionalProperties" => false
          },
          "annotations" => { "readOnlyHint" => true } },
        {
          "name" => "get_mcp_server_version",
          "description" => "Get the current version of MCP server.",
          "icons" => expected_icons,
          "inputSchema" => {
            "type" => "object",
            "properties" => {},
            "required" => []
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "create_workitem_note",
          "description" => "Create a new note (comment) on a GitLab work item",
          "icons" => expected_icons,
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "url" => {
                "type" => "string",
                "description" => "GitLab URL for the work item."
              },
              "group_id" => {
                "type" => "string",
                "description" => "ID or path of the group. Required if URL and project_path are not provided."
              },
              "project_id" => {
                "type" => "string",
                "description" => "ID or path of the project. Required if URL and group_id are not provided."
              },
              "work_item_iid" => {
                "type" => "integer",
                "description" => "Internal ID of the work item. Required if URL is not provided."
              },
              "body" => {
                "type" => "string",
                "description" => "Content of the note/comment (max 1,048,576 characters)",
                "maxLength" => 1048576
              },
              "internal" => {
                "type" => "boolean",
                "description" => "Mark note as internal (visible only to project members with Reporter role or higher)",
                "default" => false
              },
              "discussion_id" => {
                "type" => "string",
                "description" => "Global ID of the discussion to reply to (format: gid://gitlab/Discussion/<id>)"
              }
            },
            "required" => [
              "body"
            ]
          }
        },
        {
          "name" => "get_workitem_notes",
          "description" => "Get all comments (notes) for a specific work item",
          "icons" => expected_icons,
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "url" => {
                "type" => "string",
                "description" => "GitLab URL for the work item."
              },
              "group_id" => {
                "type" => "string",
                "description" => "ID or path of the group. Required if URL and project_id are not provided."
              },
              "project_id" => {
                "type" => "string",
                "description" => "ID or path of the project. Required if URL and group_id are not provided."
              },
              "work_item_iid" => {
                "type" => "integer",
                "description" => "Internal ID of the work item. Required if URL is not provided."
              },
              "after" => {
                "type" => "string",
                "description" => "Cursor for forward pagination. Use endCursor from previous response."
              },
              "before" => {
                "type" => "string",
                "description" => "Cursor for backward pagination. Use startCursor from previous response."
              },
              "first" => {
                "type" => "integer",
                "description" => "Number of notes to return after the cursor (forward pagination, max 100)",
                "minimum" => 1,
                "maximum" => 100
              },
              "last" => {
                "type" => "integer",
                "description" => "Number of notes to return before the cursor (backward pagination, max 100)",
                "minimum" => 1,
                "maximum" => 100
              }
            }
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "search_labels",
          "description" => "Search labels in a GitLab project or group",
          "icons" => expected_icons,
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "full_path" => {
                "type" => "string",
                "description" => "Full path of the project or group. Required."
              },
              "is_project" => {
                "type" => "boolean",
                "description" => "Whether to search in a project (true) or group (false). Required."
              },
              "search" => {
                "type" => "string",
                "description" => "Search term to filter labels by title."
              }
            },
            "required" => %w[full_path is_project]
          }
        }
      )
    end
    # rubocop:enable Layout/LineLength

    context 'when semantic code search is available' do
      before do
        stub_feature_flags(
          post_process_semantic_code_search_add_score: false,
          post_process_semantic_code_search_overall_confidence: false,
          post_process_semantic_code_search_group_by_file: false
        )
        # We have to use `allow_any_instance_of` since this tool is initialized
        # *on class definition time* in EE::Mcp::Tools::Manager
        allow_any_instance_of(Mcp::Tools::SemanticCodeSearchService).to receive(:available?).and_return(true) # rubocop: disable RSpec/AnyInstanceOf -- see explanation above
      end

      it 'returns the semantic_code_search in the tools list' do
        post_list_tools

        tools = json_response['result']['tools']
        semantic_code_search = tools.find { |tool| tool['name'] == 'semantic_code_search' }

        expect(semantic_code_search).not_to be_nil

        tool_description = <<~DESC.strip
          Code search using natural language.

          Returns ranked code snippets with file paths and matching content for natural-language queries.

          Primary use cases:
          - When you do not know the exact symbol or file path
          - To see how a behavior or feature is implemented across the codebase
          - To discover related implementations (clients, jobs, feature flags, background workers)

          How to use:
          - Provide a concise, specific query (1–2 sentences) with concrete keywords like endpoint, class, or framework names
          - Add directory_path to narrow scope, e.g., "app/services/" or "ee/app/workers/"
          - Prefer precise intent over broad terms (e.g., "rate limiting middleware for REST API" instead of "rate limit")

          Example queries:
          - semantic_query: "JWT verification middleware" with directory_path: "app/"
          - semantic_query: "CI pipeline triggers downstream jobs" with directory_path: "lib/"
          - semantic_query: "feature flag to disable email notifications" (no directory_path)

          Output:
          - Ranked snippets with file paths and the matched content for each hit
        DESC

        expected_icons = [Mcp::Tools::IconConfig.gitlab_icons.first.stringify_keys]

        expect(semantic_code_search).to eq(
          {
            "name" => "semantic_code_search",
            "description" => tool_description,
            "icons" => expected_icons,
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
            },
            "annotations" => { "readOnlyHint" => true }
          }
        )
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
