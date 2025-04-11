# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- needed for experiment to run
class RootCauseAnalysisHotspotExperiment < ApplicationExperiment
  control
  variant(:candidate)

  private

  def candidate_behavior; end
end
# rubocop:enable Gitlab/BoundedContexts
