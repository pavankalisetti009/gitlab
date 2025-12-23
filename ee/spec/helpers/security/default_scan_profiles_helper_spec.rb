# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DefaultScanProfilesHelper, feature_category: :security_asset_inventories do
  describe '.default_scan_profiles' do
    it 'returns an array of default scan profiles' do
      profiles = described_class.default_scan_profiles

      expect(profiles).to be_an(Array)
      expect(profiles).to all(be_a(Security::ScanProfile))
    end

    it 'includes the secret_detection scan profile' do
      profiles = described_class.default_scan_profiles

      expect(profiles.map(&:scan_type)).to include('secret_detection')
    end
  end

  describe '.build_secret_detection_scan_profile' do
    subject(:profile) { described_class.build_secret_detection_scan_profile }

    it 'creates a secret detection scan profile' do
      expect(profile).to be_a(Security::ScanProfile)
      expect(profile.scan_type).to eq('secret_detection')
    end

    it 'sets the correct attributes' do
      expect(profile).to have_attributes(
        name: 'Secret Push Protection (default)',
        gitlab_recommended: true,
        scan_type: 'secret_detection',
        description: "GitLab's recommended baseline protection using industry-standard detection rules. " \
          "Blocks common secrets like API keys, tokens, and passwords from being committed " \
          "to your repository, with detection optimized to minimize false positives"
      )
    end

    it 'configures a git_push_event trigger' do
      expect(profile.scan_profile_triggers.size).to eq(1)
      expect(profile.scan_profile_triggers.first.trigger_type).to eq('git_push_event')
    end
  end
end
