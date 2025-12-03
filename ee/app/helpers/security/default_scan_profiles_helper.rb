# frozen_string_literal: true

module Security
  module DefaultScanProfilesHelper
    def self.default_scan_profiles
      [
        build_secret_detection_scan_profile
      ]
    end

    def self.build_secret_detection_scan_profile
      Security::ScanProfile.new(
        scan_type: :secret_detection,
        name: 'Secret Push Protection (default)',
        description: "GitLab's recommended baseline protection using industry-standard detection rules. " \
          "Blocks common secrets like API keys, tokens, and passwords from being committed " \
          "to your repository, with detection optimized to minimize false positives",
        gitlab_recommended: true
      )
    end
  end
end
