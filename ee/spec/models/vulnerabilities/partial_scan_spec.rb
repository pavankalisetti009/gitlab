# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::PartialScan, feature_category: :vulnerability_management do
  describe 'validations' do
    subject(:partial_scan) { build(:vulnerabilities_partial_scan) }

    it { is_expected.to validate_presence_of(:scan) }
    it { is_expected.to validate_presence_of(:mode) }
  end

  describe 'creation' do
    let_it_be(:scan) { create(:security_scan) }

    it 'sets attributes from scan' do
      partial_scan = described_class.create!(mode: :differential, scan: scan)

      expect(partial_scan.project).to eq(scan.project)
      expect(partial_scan.pipeline).to eq(scan.pipeline)
      expect(partial_scan.scan_type).to eq(scan.scan_type)
    end
  end
end
