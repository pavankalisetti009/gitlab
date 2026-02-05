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
        name: 'Secret Detection (default)',
        description: "Protect your repository from leaked secrets like API keys, tokens, and passwords. " \
          "This profile uses industry-standard rules optimized to minimize false positives. " \
          "Enable scans on push events to block secrets before they're committed. " \
          "Enable scans in merge requests to catch secrets that were previously committed " \
          "or bypassed real-time protection. For complete coverage, we recommend enabling both.",
        gitlab_recommended: true,
        scan_profile_triggers_attributes: [
          trigger_type: :git_push_event
        ]
      )
    end
  end
end
