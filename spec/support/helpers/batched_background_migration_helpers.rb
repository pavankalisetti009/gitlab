# frozen_string_literal: true

# Batched Background Migration Spec Helpers
#
# This library provides versioned helper utilities for writing batched background
# migration specs with reduced boilerplate and improved maintainability.
#
# ## Versioning
#
# The helpers are versioned to allow for modifications without breaking existing
# migration specs. When changes are needed, a new version can be created while
# keeping older versions intact.
#
# ## Available Versions
#
# - V1: Initial version with table helpers
#
# ## Usage
#
# Include the desired version in your migration spec:
#
#   RSpec.describe Gitlab::BackgroundMigration::BackfillProjectId do
#     include Gitlab::BackgroundMigration::SpecHelpers::V1
#
#     it 'backfills project_id' do
#       project = projects.create!(name: 'test')
#       issue = issues.create!(project_id: project.id)
#     end
#   end
#
# ## Migration Guide
#
# When a new version is released, existing specs can continue using their current
# version. New specs should use the latest version unless there's a specific reason
# to use an older version.
#
# To migrate from manual table definitions to V1:
#
# Before:
#   let!(:projects) { table(:projects) }
#   let!(:issues) { table(:issues) }
#
# After:
#   include Gitlab::BackgroundMigration::SpecHelpers::V1
#   # Tables are now automatically available

require_relative 'batched_background_migration_helpers/v1'

module Gitlab
  module BackgroundMigration
    module SpecHelpers
      # Latest stable version
      LATEST_VERSION = V1
    end
  end
end
