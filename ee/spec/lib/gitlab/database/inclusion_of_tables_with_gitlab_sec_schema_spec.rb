# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'inclusion of tables with gitlab_sec schema', feature_category: :vulnerability_management do
  # During the decomposition of Sec related tables into gitlab_sec we want to ensure all tables tied
  # to `gitlab_sec` schema are properly configured.
  # As part of this, we ensure the base class is properly configured.

  it 'ensures tables belonging to `gitlab_sec` schema are properly configured' do
    gitlab_sec_schema_tables.each do |table|
      table.classes.each do |klass|
        expect(klass.constantize.ancestors).to include(
          Gitlab::Database::SecApplicationRecord
        ), error_message(table.table_name)
      end
    end
  end

  private

  def error_message(table_name)
    <<~HEREDOC
      The table `#{table_name}` has been added with `gitlab_sec` schema but
      does not inherit from the correct ActiveRecord connection base class.

      Please see issue https://gitlab.com/gitlab-org/gitlab/-/issues/483554 to understand why this change is being enforced.
    HEREDOC
  end

  def gitlab_sec_schema_tables
    ::Gitlab::Database::Dictionary.entries.find_all_by_schema('gitlab_sec')
  end
end
