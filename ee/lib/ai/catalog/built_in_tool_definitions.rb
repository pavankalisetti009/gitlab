# frozen_string_literal: true

module Ai
  module Catalog
    module BuiltInToolDefinitions
      extend ActiveSupport::Concern

      ITEMS = [
        {
          id: 1,
          name: "gitlab_blob_search",
          title: "Gitlab Blob Search",
          description: "Search for blobs in the specified GitLab group or project. In GitLab, a \"blob\" " \
            "refers to a file's content in a specific version of the repository."
        },
        {
          id: 2,
          name: "ci_linter",
          title: "Ci Linter",
          description: "Validates a CI/CD YAML configuration against GitLab CI syntax rules in the context " \
            "of the project. This tool can be used when you have a project_id and the content " \
            "of the CI/CD YAML configuration and will return a JSON response indicating whether " \
            "the configuration is valid or not, along with any errors found."
        },
        {
          id: 3,
          name: "run_git_command",
          title: "Run Git Command",
          description: "Runs a git command in the repository working directory."
        },
        {
          id: 4,
          name: "gitlab_commit_search",
          title: "Gitlab Commit Search",
          description: "Search for commits in the specified GitLab project or group."
        },
        {
          id: 5,
          name: "create_epic",
          title: "Create Epic",
          description: "Create a new epic in a GitLab group."
        },
        {
          id: 6,
          name: "create_issue",
          title: "Create Issue",
          description: "Create a new issue in a GitLab project."
        },
        {
          id: 7,
          name: "create_issue_note",
          title: "Create Issue Note",
          description: "Create a new note (comment) on a GitLab issue."
        },
        {
          id: 8,
          name: "create_merge_request",
          title: "Create Merge Request",
          description: "Create a new merge request in the specified project."
        },
        {
          id: 9,
          name: "create_merge_request_note",
          title: "Create Merge Request Note",
          description: "Create a note (comment) on a merge request. You are NOT allowed to ever use a " \
            "GitLab quick action in a merge request note."
        },
        {
          id: 10,
          name: "edit_file",
          title: "Edit File",
          description: "Use this tool to edit an existing file."
        },
        {
          id: 11,
          name: "find_files",
          title: "Find Files",
          description: "Find files, recursively, with names matching a specific pattern in the repository."
        },
        {
          id: 12,
          name: "get_commit",
          title: "Get Commit",
          description: "Get a single commit from a GitLab project repository."
        },
        {
          id: 13,
          name: "get_commit_comments",
          title: "Get Commit Comments",
          description: "Get the comments on a specific commit in a GitLab project."
        },
        {
          id: 14,
          name: "get_commit_diff",
          title: "Get Commit Diff",
          description: "Get the diff of a specific commit in a GitLab project."
        },
        {
          id: 15,
          name: "get_epic",
          title: "Get Epic",
          description: "Get a single epic in a GitLab group"
        },
        {
          id: 16,
          name: "get_epic_note",
          title: "Get Epic Note",
          description: "Get a single note (comment) from a specific epic."
        },
        {
          id: 17,
          name: "get_issue",
          title: "Get Issue",
          description: "Get a single issue in a GitLab project."
        },
        {
          id: 18,
          name: "get_issue_note",
          title: "Get Issue Note",
          description: "Get a single note (comment) from a specific issue."
        },
        {
          id: 19,
          name: "get_job_logs",
          title: "Get Job Logs",
          description: "Get the trace for a job."
        },
        {
          id: 20,
          name: "get_merge_request",
          title: "Get Merge Request",
          description: "Fetch details about the merge request."
        },
        {
          id: 21,
          name: "get_pipeline_errors",
          title: "Get Pipeline Errors",
          description: "Get the logs for failed jobs in the latest pipeline in a merge request."
        },
        {
          id: 22,
          name: "get_project",
          title: "Get Project",
          description: "Fetch details about the project"
        },
        {
          id: 23,
          name: "get_repository_file",
          title: "Get Repository File",
          description: "Get the contents of a file from a remote repository."
        },
        {
          id: 24,
          name: "grep",
          title: "Grep",
          description: "Search for text patterns in files. This tool uses searches, recursively, through " \
            "all files in the given directory, respecting .gitignore rules."
        },
        {
          id: 25,
          name: "gitlab_group_project_search",
          title: "Gitlab Group Project Search",
          description: "Search for projects within a specified GitLab group."
        },
        {
          id: 26,
          name: "gitlab_issue_search",
          title: "Gitlab Issue Search",
          description: "Search for issues in the specified GitLab project or group."
        },
        {
          id: 27,
          name: "list_all_merge_request_notes",
          title: "List All Merge Request Notes",
          description: "List all notes (comments) on a merge request."
        },
        {
          id: 28,
          name: "list_commits",
          title: "List Commits",
          description: "List commits in a GitLab project repository."
        },
        {
          id: 29,
          name: "list_dir",
          title: "List Dir",
          description: "Lists files in the given directory relative to the root of the project."
        },
        {
          id: 30,
          name: "list_epic_notes",
          title: "List Epic Notes",
          description: "Get a list of all notes (comments) for a specific epic."
        },
        {
          id: 31,
          name: "list_epics",
          title: "List Epics",
          description: "Get all epics of the requested group and its subgroups."
        },
        {
          id: 32,
          name: "list_issue_notes",
          title: "List Issue Notes",
          description: "Get a list of all notes (comments) for a specific issue."
        },
        {
          id: 33,
          name: "list_issues",
          title: "List Issues",
          description: "List issues in a GitLab project."
        },
        {
          id: 34,
          name: "list_merge_request_diffs",
          title: "List Merge Request Diffs",
          description: "Fetch the diffs of the files changed in a merge request."
        },
        {
          id: 35,
          name: "gitlab_merge_request_search",
          title: "Gitlab Merge Request Search",
          description: "Search for merge requests in the specified GitLab project or group."
        },
        {
          id: 36,
          name: "gitlab_milestone_search",
          title: "Gitlab Milestone Search",
          description: "Search for milestones in the specified GitLab project or group."
        },
        {
          id: 37,
          name: "mkdir",
          title: "Mkdir",
          description: "Create a new directory using the mkdir command. The directory creation is " \
            "restricted to the current working directory tree."
        },
        {
          id: 38,
          name: "gitlab_note_search",
          title: "Gitlab Note Search",
          description: "Search for notes in the specified GitLab project."
        },
        {
          id: 39,
          name: "read_file",
          title: "Read File",
          description: "Read the contents of a file."
        },
        {
          id: 40,
          name: "run_command",
          title: "Run Command",
          description: "Run a bash command in the current working directory. Following bash commands are " \
            "not supported: git and will result in error.Pay extra attention to correctly " \
            "escape special characters like '`'"
        },
        {
          id: 41,
          name: "set_task_status",
          title: "Set Task Status",
          description: "Set the status of a single task in the plan"
        },
        {
          id: 42,
          name: "update_epic",
          title: "Update Epic",
          description: "Update an existing epic in a GitLab group."
        },
        {
          id: 43,
          name: "update_issue",
          title: "Update Issue",
          description: "Update an existing issue in a GitLab project."
        },
        {
          id: 44,
          name: "update_merge_request",
          title: "Update Merge Request",
          description: "Updates an existing merge request. You can change the target branch, title, or " \
            "even close the MR."
        },
        {
          id: 45,
          name: "gitlab__user_search",
          title: "Gitlab User Search",
          description: "Search for users in the specified GitLab project or group."
        },
        {
          id: 46,
          name: "gitlab_wiki_blob_search",
          title: "Gitlab Wiki Blob Search",
          description: "Search for wiki blobs in the specified GitLab project or group. In GitLab, a " \
            "\"blob\" refers to a file's content in a specific version of the repository."
        },
        {
          id: 47,
          name: "create_file_with_contents",
          title: "Create File With Contents",
          description: "Create and write the given contents to a file. Please specify the `file_path` " \
            "and the `contents` to write."
        },
        {
          id: 48,
          name: "gitlab_documentation_search",
          title: "Gitlab Documentation Search",
          description: "Find GitLab documentations, " \
            "useful for answering questions concerning GitLab and its features, e.g.: " \
            "projects, groups, issues, merge requests, epics, milestones, labels, " \
            "CI/CD pipelines, git repositories, and more. " \
            "Parameters: " \
            "- search: The search term (required) " \
            "An example tool_call is presented below " \
            "{ " \
            "'id': 'toolu_01KqpqRQhTM2pxJrhtTscMWu', " \
            "'name': 'gitlab_documentation_search', " \
            "'type': 'tool_use' " \
            "'input': { " \
            "'search': 'How do I set up a new project?', " \
            "}, " \
            "}"
        },
        {
          id: 49,
          name: "get_current_user",
          title: "Get Current User",
          description: "Get the current user information from GitLab API. " \
            "Only the following information will be retrieved from the current user endpoint: " \
            "- user name " \
            "- job title " \
            "- preferred languages (written in ISO 639-1 language code)"
        },
        {
          id: 50,
          name: "add_new_task",
          title: "Add New Task",
          description: "Add a task to a plan for a workflow. " \
            "A plan consists of a list of tasks and the status of each task. " \
            "This tool adds a task to the list of tasks but should never update the status of a task."
        },
        {
          id: 51,
          name: "create_vulnerability_issue",
          title: "Create Vulnerability Issue",
          description: "Create a GitLab issue linked to security vulnerabilities in a GitLab project using GraphQL. " \
            "The project must be specified using its full path " \
            "(e.g., 'namespace/project' or 'group/subgroup/project'). " \
            "The tool supports creating a GitLab issue linked to vulnerabilities by ID. " \
            "Up to 100 IDs of vulnerabilities can be provided. " \
            "For example: " \
            "- Create an issue for project ID 1 linked with vulnerabilities with ID 2 and 3: " \
            "create_vulnerability_issue( " \
            "project_full_path=\"namespace/project\", " \
            "vulnerability_ids=[\"gid://gitlab/Vulnerability/2\", \"gid://gitlab/Vulnerability/3\"] " \
            ")"
        },
        {
          id: 52,
          name: "read_files",
          title: "Read Files",
          description: "Read one or more files in a single operation."
        },
        {
          id: 53,
          name: "get_work_item",
          title: "Get Work Item",
          description: "Get a single work item in a GitLab group or project. " \
            "To identify a work item you must provide either: " \
            "- group_id/project_id and work_item_iid " \
            "- group_id can be either a numeric ID (e.g., 42) or a path string " \
            "(e.g., 'my-group' or 'namespace/subgroup') " \
            "- project_id can be either a numeric ID (e.g., 13) or a path string " \
            "(e.g., 'namespace/project') " \
            "- work_item_iid is always a numeric value (e.g., 7) " \
            "- or a GitLab URL like: " \
            "- https://gitlab.com/groups/namespace/group/-/work_items/42 " \
            "- https://gitlab.com/namespace/project/-/work_items/42 " \
            "For example: " \
            "- Given group_id 'namespace/group' and work_item_iid 42, the tool call would be: " \
            "get_work_item(group_id='namespace/group', work_item_iid=42) " \
            "- Given project_id 'namespace/project' and work_item_iid 42, the tool call would be: " \
            "get_work_item(project_id='namespace/project', work_item_iid=42) " \
            "- Given the URL https://gitlab.com/groups/namespace/group/-/work_items/42, " \
            "the tool call would be: " \
            "get_work_item(url=\"https://gitlab.com/groups/namespace/group/-/work_items/42\") " \
            "- Given the URL https://gitlab.com/namespace/project/-/work_items/42, " \
            "the tool call would be: " \
            "get_work_item(url=\"https://gitlab.com/namespace/project/-/work_items/42\")"
        },
        {
          id: 54,
          name: "create_plan",
          title: "Create Plan",
          description: "Create a list of tasks for the plan.    " \
            "The tasks you provide here will set the tasks in the current plan.    " \
            "Please provide all the tasks that you want to show to the user.    " \
            "Tasks should be formatted in an array where each task is a string."
        },
        {
          id: 55,
          name: "get_plan",
          title: "Get Plan",
          description: "Fetch a list of tasks for a workflow.    " \
            "A plan consists of a list of tasks and the status of each task."
        },
        {
          id: 56,
          name: "update_task_description",
          title: "Update Task Description",
          description: "Update the description of a task in the plan.    " \
            "A plan consists of a list of tasks and the status of each task.    " \
            "This tool updates the description of a task but should never update the status of a task."
        },
        {
          id: 57,
          name: "revert_to_detected_vulnerability",
          title: "Revert To Detected Vulnerability",
          description: "Revert a vulnerability's state back to 'detected' status in GitLab using GraphQL.    " \
            "The vulnerability is identified by its GitLab internal ID, which can be obtained from the    " \
            "list_vulnerabilities tool. An optional comment can be provided to explain the reason for reverti" \
            "ng.    " \
            "For example:    " \
            "- Revert a vulnerability without comment:        " \
            "revert_to_detected_vulnerability(vulnerability_id=\"gid://gitlab/Vulnerability/123\")    " \
            "- Revert with explanation:        " \
            "revert_to_detected_vulnerability(vulnerability_id=\"gid://gitlab/Vulnerability/123\", commen" \
            "t=\"Reverting for re-assessment after code changes\")"
        },
        {
          id: 58,
          name: "get_previous_session_context",
          title: "Get Previous Session Context",
          description: "Get context from a previously run session.    " \
            "This tool retrieves context from a previously run specified session.    " \
            "Only use it when prompted by the user to reference a previously executed session.    " \
            "Do not provide context for any other session unless explicitly asked.    " \
            "Args:        " \
            "previous_session_id: The ID of a previously-run session to get context for    " \
            "Returns:        " \
            "A JSON string containing context data from a previous session or an error message if the con" \
            "text could not be retrieved."
        },
        {
          id: 59,
          name: "list_repository_tree",
          title: "List Repository Tree",
          description: "List files and directories in a GitLab repository.    " \
            "To identify a project you must provide either:    " \
            "- project_id parameter, or    " \
            "- A GitLab URL like:        " \
            "- https://gitlab.com/namespace/project        " \
            "- https://gitlab.com/group/subgroup/project    " \
            "You can specify a path to get contents of a subdirectory, a specific ref (branch/tag),    " \
            "and whether to get a recursive tree.    " \
            "For example:    " \
            "- Given project_id 13, the tool call would be:        " \
            "list_repository_tree(project_id=13)    " \
            "- To list files in a specific subdirectory with a specific branch:        " \
            "list_repository_tree(project_id=13, path=\"src\", ref=\"main\")    " \
            "- To recursively list all files in a project:        " \
            "list_repository_tree(project_id=13, recursive=True)"
        },
        {
          id: 60,
          name: "create_work_item_note",
          title: "Create Work Item Note",
          description: "Create a new note (comment) on a GitLab work item.    " \
            "You are NOT allowed to ever use a GitLab quick action in work item description" \
            "or work item note body. Quick actions are text-based shortcuts for common GitLab actions. They are c" \
            "ommands that are" \
            "on their own line and start with a backslash. Examples include /merge, /approve, /close, etc.    " \
            "To identify a work item you must provide either:" \
            "- group_id/project_id and work_item_iid    " \
            "- group_id can be either a numeric ID (e.g., 42) or a path string (e.g., 'my-group' or 'namespac" \
            "e/subgroup')    " \
            "- project_id can be either a numeric ID (e.g., 13) or a path string (e.g., 'namespace/project')    " \
            "- work_item_iid is always a numeric value (e.g., 7)" \
            "- or a GitLab URL like:    " \
            "- https://gitlab.com/groups/namespace/group/-/work_items/42    " \
            "- https://gitlab.com/namespace/project/-/work_items/42    " \
            "For example:    " \
            "- Given group_id 'namespace/group', work_item_iid 42, and body \"This is a comment\", the tool c" \
            "all would be:        " \
            "create_work_item_note(group_id='namespace/group', work_item_iid=42, body=\"This is a comment" \
            "\")    " \
            "- Given project_id 'namespace/project', work_item_iid 42, and body \"This is a comment\", the to" \
            "ol call would be:        " \
            "create_work_item_note(project_id='namespace/project', work_item_iid=42, body=\"This is a com" \
            "ment\")    " \
            "- Given the URL https://gitlab.com/groups/namespace/group/-/work_items/42 and body \"This is a c" \
            "omment\", the tool call would be:        " \
            "create_work_item_note(url=\"https://gitlab.com/groups/namespace/group/-/work_items/42\", bod" \
            "y=\"This is a comment\")    " \
            "- Given the URL https://gitlab.com/namespace/project/-/work_items/42 and body \"This is a commen" \
            "t\", the tool call would be:        " \
            "create_work_item_note(url=\"https://gitlab.com/namespace/project/-/work_items/42\", body=\"T" \
            "his is a comment\")    " \
            "The body parameter is always required."
        },
        {
          id: 61,
          name: "remove_task",
          title: "Remove Task",
          description: "Remove a task from a plan based on its ID.    " \
            "A plan consists of a list of tasks and the status of each task.    " \
            "This tool removes a task from the list of tasks."
        },
        {
          id: 62,
          name: "update_vulnerability_severity",
          title: "Update Vulnerability Severity",
          description: "Update the severity level of vulnerabilities in a GitLab project using GraphQL. " \
            "The project must be specified using its full path " \
            "(e.g., 'namespace/project' or 'group/subgroup/project'). " \
            "This tool allows you to override the severity level of one or more vulnerabilities " \
            "and provide a comment explaining the change. " \
            "The severity must be one of: CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN. " \
            "A comment explaining the reason for the severity change is required " \
            "and can be up to 50,000 characters. " \
            "For example: " \
            "- Update single vulnerability severity: " \
            "update_vulnerability_severity( " \
            "vulnerability_ids=[\"gid://gitlab/Vulnerability/123\"], " \
            "severity=\"HIGH\", " \
            "comment=\"Updated severity based on security review\" " \
            ") " \
            "- Update multiple vulnerabilities: " \
            "update_vulnerability_severity( " \
            "vulnerability_ids=[\"gid://gitlab/Vulnerability/123\", " \
            "\"gid://gitlab/Vulnerability/456\"], " \
            "severity=\"LOW\", " \
            "comment=\"These are false positives based on code analysis\" " \
            ")"
        },
        {
          id: 63,
          name: "list_project_audit_events",
          title: "List Project Audit Events",
          description: "List audit events for a GitLab project.    " \
            "**Access Requirements**: Only project owners can access project audit events.    " \
            "**Confidentiality**: Audit events contain sensitive security and compliance information.    " \
            "Do not share these events outside of this chat conversation.    " \
            "To identify the project you must provide either:    " \
            "- project_id parameter, or    " \
            "- A GitLab URL like:        " \
            "- https://gitlab.com/namespace/project        " \
            "- https://gitlab.com/group/subgroup/project    " \
            "Examples:    " \
            "- List audit events for project with ID 7:        " \
            "list_project_audit_events(project_id=7)    " \
            "- List audit events for project by URL:        " \
            "list_project_audit_events(url=\"https://gitlab.com/gitlab-org/gitlab\")    " \
            "- List recent audit events:        " \
            "list_project_audit_events(project_id=7, created_after=\"2023-01-01T00:00:00Z\")"
        },
        {
          id: 64,
          name: "list_group_audit_events",
          title: "List Group Audit Events",
          description: "List audit events for a GitLab group.    " \
            "**Access Requirements**: Only group owners can access group audit events.    " \
            "**Confidentiality**: Audit events contain sensitive security and compliance information.    " \
            "Do not share these events outside of this chat conversation.    " \
            "To identify the group you must provide either:    " \
            "- group_id parameter, or    " \
            "- group_path parameter (the URL-encoded path of the group)    " \
            "Examples:    " \
            "- List audit events for group with ID 60:        " \
            "list_group_audit_events(group_id=60)    " \
            "- List audit events for group by path:        " \
            "list_group_audit_events(group_path=\"gitlab-org/gitlab\")    " \
            "- List recent audit events:        " \
            "list_group_audit_events(group_id=60, created_after=\"2023-01-01T00:00:00Z\")"
        },
        {
          id: 65,
          name: "link_vulnerability_to_issue",
          title: "Link Vulnerability To Issue",
          description: "Link a GitLab issue to security vulnerabilities in a GitLab project using GraphQL.    " \
            "" \
            "The project must be specified using its full path (e.g., 'namespace/project' or 'group/subgroup/proj" \
            "ect').    " \
            "The tool supports linking a GitLab issue to vulnerabilities by ID.    " \
            "Up to 100 IDs of vulnerabilities can be provided.    " \
            "For example:    " \
            "- Link issue with ID 1 to a vulnerabilities with ID 23 and 10:        " \
            "link_vulnerability_to_issue(            " \
            "issue_id=\"gid://gitlab/Issue/1\",            " \
            "vulnerability_ids=[\"gid://gitlab/Vulnerability/23\", \"gid://gitlab/Vulnerability/10\"]        " \
            ")"
        },
        {
          id: 66,
          name: "list_instance_audit_events",
          title: "List Instance Audit Events",
          description: "List instance-level audit events in GitLab.    " \
            "**Access Requirements**: Only instance administrators can access instance audit events.    " \
            "**Confidentiality**: Audit events contain sensitive security and compliance information.    " \
            "Do not share these events outside of this chat conversation.    " \
            "Examples:    " \
            "- List all instance audit events:        " \
            "list_instance_audit_events()    " \
            "- List audit events for a specific entity:        " \
            "list_instance_audit_events(entity_type=\"Project\", entity_id=6)    " \
            "- List audit events created after a certain date:        " \
            "list_instance_audit_events(created_after=\"2023-01-01T00:00:00Z\")"
        },
        {
          id: 67,
          name: "get_vulnerability_details",
          title: "Get Vulnerability Details",
          description: "Get detailed information about a specific vulnerability using its numeric ID.    " \
            "The vulnerability ID should be just the numeric identifier (e.g., '567').    " \
            "This tool provides comprehensive details including:    " \
            "- Basic vulnerability information (title, state, description, severity)    " \
            "- Location details (file paths, line numbers, etc.)    " \
            "- CVE enrichment data (EPSS scores, known exploits)    " \
            "- Detection pipeline information    " \
            "- Detailed vulnerability report data with nested structures    " \
            "For example:        " \
            "get_vulnerability_details(vulnerability_id=\"567\")"
        },
        {
          id: 68,
          name: "dismiss_vulnerability",
          title: "Dismiss Vulnerability",
          description: "Dismiss a security vulnerability in a GitLab project using GraphQL.    " \
            "" \
            "The project must be specified using its full path (e.g., 'namespace/project' or 'group/subgroup/proj" \
            "ect').    " \
            "The tool supports dismissing a vulnerability by ID, with a dismissal reason, and comment.    " \
            "The dismiss reason must be one of: ACCEPTABLE_RISK, FALSE_POSITIVE, MITIGATING_CONTROL, USED_IN_" \
            "TESTS, NOT_APPLICABLE.    " \
            "If a dismissal reason is not given, you will need to ask for one.    " \
            "A comment explaining the reason for the dismissal is required and can be up to 50,000 characters" \
            ".    " \
            "If a comment is not given, you will need to ask for one.    " \
            "For example:    " \
            "- Dismiss a vulnerability for being a false positive:        " \
            "dismiss_vulnerability(            " \
            "vulnerability_id=\"gid://gitlab/Vulnerability/123\",            " \
            "dismissal_reason=\"FALSE_POSITIVE\",            " \
            "comment=\"Security review deemed this a false positive\"        " \
            ")"
        },
        {
          id: 69,
          name: "confirm_vulnerability",
          title: "Confirm Vulnerability",
          description: "Confirm a security vulnerability in a GitLab project. " \
            "This tool marks a vulnerability as confirmed, changing its state to CONFIRMED. " \
            "This is typically done when a security team has verified that the vulnerability " \
            "is a real issue that needs to be addressed."
        },
        {
          id: 70,
          name: "update_work_item",
          title: "Update Work Item",
          description: "Update an existing work item in a GitLab group or project.    " \
            "You are NOT allowed to ever use a GitLab quick action in work item description" \
            "or work item note body. Quick actions are text-based shortcuts for common GitLab actions. They are c" \
            "ommands that are" \
            "on their own line and start with a backslash. Examples include /merge, /approve, /close, etc.    " \
            "To identify a work item you must provide either:" \
            "- group_id/project_id and work_item_iid    " \
            "- group_id can be either a numeric ID (e.g., 42) or a path string (e.g., 'my-group' or 'namespac" \
            "e/subgroup')    " \
            "- project_id can be either a numeric ID (e.g., 13) or a path string (e.g., 'namespace/project')    " \
            "- work_item_iid is always a numeric value (e.g., 7)" \
            "- or a GitLab URL like:    " \
            "- https://gitlab.com/groups/namespace/group/-/work_items/42    " \
            "- https://gitlab.com/namespace/project/-/work_items/42    " \
            "For example:    " \
            "- update_work_item(group_id='parent/child', work_item_iid=42, title=\"Updated title\")    " \
            "- update_work_item(project_id='namespace/project', work_item_iid=42, title=\"Updated title\")    " \
            "- update_work_item(url=\"https://gitlab.com/groups/namespace/group/-/work_items/42\", title=\"Up" \
            "dated title\")    " \
            "- update_work_item(url=\"https://gitlab.com/namespace/project/-/work_items/42\", title=\"Updated " \
            "title\")"
        },
        {
          id: 71,
          name: "list_work_items",
          title: "List Work Items",
          description: "List work items in a GitLab project or group.    " \
            "By default, only returns the first 20 work items. Use 'after' parameter with the    " \
            "endCursor from previous responses to fetch subsequent pages.    " \
            "To identify the parent (group or project) you must provide either:" \
            "- group_id parameter, or" \
            "- project_id parameter, or" \
            "- A GitLab URL like:    " \
            "- https://gitlab.com/namespace/group    " \
            "- https://gitlab.com/groups/namespace/group    " \
            "- https://gitlab.com/namespace/project    " \
            "- https://gitlab.com/namespace/group/project    " \
            "This tool only supports the following types: (Epic, Issue, Key Result, Objective, Task)    " \
            "For example:    " \
            "- Given group_id 'namespace/group', the tool call would be:        " \
            "list_work_items(group_id='namespace/group')    " \
            "- Given project_id 'namespace/project', the tool call would be:        " \
            "list_work_items(project_id='namespace/project')    " \
            "- Given the URL https://gitlab.com/groups/namespace/group, the tool call would be:        " \
            "list_work_items(url=\"https://gitlab.com/groups/namespace/group\")    " \
            "- Given the URL https://gitlab.com/namespace/project, the tool call would be:        " \
            "list_work_items(url=\"https://gitlab.com/namespace/project\")"
        },
        {
          id: 72,
          name: "create_commit",
          title: "Create Commit",
          description: "Create a commit with multiple file actions in a GitLab repository.    " \
            "To identify the project you must provide either:    " \
            "- project_id parameter, or    " \
            "- A GitLab URL like:      " \
            "- https://gitlab.com/namespace/project      " \
            "- https://gitlab.com/namespace/project/-/commits      " \
            "- https://gitlab.com/group/subgroup/project      " \
            "- https://gitlab.com/group/subgroup/project/-/commits    " \
            "Actions can include creating, updating, deleting, moving, or changing file permissions.    " \
            "Each action requires at minimum an 'action' type and 'file_path'.    " \
            "For example:    " \
            "- Creating a new file requires 'action': 'create', 'file_path', and 'content'    " \
            "- Updating a file requires 'action': 'update', 'file_path', and 'content'    " \
            "- Deleting a file requires 'action': 'delete' and 'file_path'    " \
            "- Moving a file requires 'action': 'move', 'file_path', and 'previous_path'"
        },
        {
          id: 73,
          name: "list_vulnerabilities",
          title: "List Vulnerabilities",
          description: "List security vulnerabilities in a GitLab project using GraphQL.    " \
            "" \
            "The project must be specified using its full path (e.g., 'namespace/project' or 'group/subgroup/proj" \
            "ect').    " \
            "The tool supports filtering vulnerabilities by:    " \
            "- Severity levels (can specify multiple: CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN)    " \
            "- Report type (SAST, DAST, DEPENDENCY_SCANNING, etc.)    " \
            "For example:    " \
            "- List all vulnerabilities in a project:        " \
            "list_vulnerabilities(project_full_path=\"namespace/project\")    " \
            "- List only critical and high vulnerabilities in a project:        " \
            "list_vulnerabilities(            " \
            "project_full_path=\"namespace/project\",            " \
            "severity=[VulnerabilitySeverity.CRITICAL, VulnerabilitySeverity.HIGH]        " \
            ")    " \
            "- List only SAST vulnerabilities in a project:        " \
            "list_vulnerabilities(            " \
            "project_full_path=\"namespace/project\",            " \
            "report_type=[VulnerabilityReportType.SAST]        " \
            ")    " \
            "- List only critical SAST vulnerabilities in a project:        " \
            "list_vulnerabilities(            " \
            "project_full_path=\"namespace/project\",            " \
            "severity=[VulnerabilitySeverity.CRITICAL]            " \
            "report_type=[VulnerabilityReportType.SAST]        " \
            ")"
        },
        {
          id: 74,
          name: "get_work_item_notes",
          title: "Get Work Item Notes",
          description: "Get all comments (notes) for a specific work item.    " \
            "To identify a work item you must provide either:" \
            "- group_id/project_id and work_item_iid    " \
            "- group_id can be either a numeric ID (e.g., 42) or a path string (e.g., 'my-group' or 'namespac" \
            "e/subgroup')    " \
            "- project_id can be either a numeric ID (e.g., 13) or a path string (e.g., 'namespace/project')    " \
            "- work_item_iid is always a numeric value (e.g., 7)" \
            "- or a GitLab URL like:    " \
            "- https://gitlab.com/groups/namespace/group/-/work_items/42    " \
            "- https://gitlab.com/namespace/project/-/work_items/42    " \
            "For example:    " \
            "- Given group_id 'namespace/group' and work_item_iid 42, the tool call would be:        " \
            "get_work_item_notes(group_id='namespace/group', work_item_iid=42)    " \
            "- Given project_id 'namespace/project' and work_item_iid 42, the tool call would be:        " \
            "get_work_item_notes(project_id='namespace/project', work_item_iid=42)    " \
            "- Given the URL https://gitlab.com/groups/namespace/group/-/work_items/42, the tool call would b" \
            "e:        " \
            "get_work_item_notes(url=\"https://gitlab.com/groups/namespace/group/-/work_items/42\")    " \
            "- Given the URL https://gitlab.com/namespace/project/-/work_items/42, the tool call would be:        " \
            "get_work_item_notes(url=\"https://gitlab.com/namespace/project/-/work_items/42\")"
        },
        {
          id: 75,
          name: "create_work_item",
          title: "Create Work Item",
          description: "Create a new work item in a GitLab group or project.    " \
            "You are NOT allowed to ever use a GitLab quick action in work item description" \
            "or work item note body. Quick actions are text-based shortcuts for common GitLab actions. They are c" \
            "ommands that are" \
            "on their own line and start with a backslash. Examples include /merge, /approve, /close, etc.    " \
            "To identify the parent (group or project) you must provide either:" \
            "- group_id parameter, or" \
            "- project_id parameter, or" \
            "- A GitLab URL like:    " \
            "- https://gitlab.com/namespace/group    " \
            "- https://gitlab.com/groups/namespace/group    " \
            "- https://gitlab.com/namespace/project    " \
            "- https://gitlab.com/namespace/group/project    " \
            "For example:    " \
            "- Given group_id 'namespace/group' and title \"Implement feature X\", the tool call would be:        " \
            "create_work_item(group_id='namespace/group', title=\"Implement feature X\", type_name=\"issu" \
            "e\")"
        },
        {
          id: 76,
          name: "get_wiki_page",
          title: "Get Wiki Page",
          description: "Get a single wiki page from a GitLab project or group, including all its comments.    " \
            "You must provide the slug of the wiki page together with either project_id or group_id.    " \
            "Both project_id and group_id must be provided as full path strings (e.g., 'namespace/project' " \
            "or 'namespace/group').    " \
            "The slug is a unique string identifier for the wiki page (nested pages use forward slashes, " \
            "e.g., 'dir/page_name').    " \
            "For example:    " \
            "- Given project_id \"namespace/project\" and slug \"home\", the tool call would be:        " \
            "get_wiki_page(project_id=\"namespace/project\", slug=\"home\")    " \
            "- Given group_id \"namespace/group\" and slug \"documentation\", the tool call would be:        " \
            "get_wiki_page(group_id=\"namespace/group\", slug=\"documentation\")    " \
            "- For nested wiki pages, include the path segments in the slug:        " \
            "get_wiki_page(project_id=\"namespace/project\", slug=\"dir/page_name\")"
        }
      ].freeze
    end
  end
end
