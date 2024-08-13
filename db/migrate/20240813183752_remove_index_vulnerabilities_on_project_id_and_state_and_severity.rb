# frozen_string_literal: true

class RemoveIndexVulnerabilitiesOnProjectIdAndStateAndSeverity < Gitlab::Database::Migration[2.2]
  milestone '17.4'

  disable_ddl_transaction!

  def change
    remove_concurrent_index_by_name :vulnerabilities, 'index_vulnerabilities_on_project_id_and_state_and_severity'
  end
end
