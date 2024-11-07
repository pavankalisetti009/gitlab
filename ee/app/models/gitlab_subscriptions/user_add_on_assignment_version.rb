# frozen_string_literal: true

module GitlabSubscriptions
  class UserAddOnAssignmentVersion < ApplicationRecord
    include PaperTrail::VersionConcern
  end
end
