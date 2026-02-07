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
          "When enabled, secrets are detected in real time during git push events and blocked " \
          "before they're committed.",
        gitlab_recommended: true,
        scan_profile_triggers_attributes: [
          trigger_type: :git_push_event
        ]
      )
    end
  end
end
