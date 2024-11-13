# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Reports::LicenseScanning::Report, feature_category: :software_composition_analysis do
  include LicenseScanningReportHelpers

  describe '#by_license_name' do
    subject { report.by_license_name(name) }

    let(:report) { build(:ci_reports_license_scanning_report, :report_2) }

    context 'with existing license' do
      let(:name) { 'MIt' }

      it 'finds right name' do
        is_expected.to be_a(Gitlab::Ci::Reports::LicenseScanning::License)
        expect(subject.name).to eq('MIT')
      end
    end

    context 'without existing license' do
      let(:name) { 'TIM' }

      it { is_expected.to be_nil }
    end
  end

  describe '#dependency_names' do
    subject { report.dependency_names }

    let(:report) { build(:license_scan_report) }

    context 'when there are multiple dependencies' do
      before do
        report.add_license(id: nil, name: 'MIT').add_dependency(name: 'Library1')
        report.add_license(id: nil, name: 'BSD').add_dependency(name: 'Library1')
        report.add_license(id: nil, name: 'WTFPL').add_dependency(name: 'Library2')
      end

      it { is_expected.to match_array(%w[Library1 Library2]) }
    end

    context 'when there are no dependencies' do
      it { is_expected.to be_empty }
    end
  end

  describe '#diff_with' do
    subject { base_report.diff_with(head_report) }

    def names_from(licenses)
      licenses.map(&:name)
    end

    context 'when the other report is not available' do
      let(:base_report) { build(:license_scan_report, :version_2) }
      let(:head_report) { nil }

      before do
        base_report
          .add_license(id: 'MIT', name: 'MIT License')
          .add_dependency(name: 'rails')
      end

      specify do
        expect(names_from(subject[:removed])).to contain_exactly('MIT License')
        expect(subject[:added]).to be_empty
        expect(subject[:unchanged]).to be_empty
      end
    end

    context 'when diffing two v1 reports' do
      let(:base_report) { build(:license_scan_report, :version_1) }
      let(:head_report) { build(:license_scan_report, :version_1) }

      before do
        base_report.add_license(id: nil, name: 'MIT').add_dependency(name: 'Library1')
        base_report.add_license(id: nil, name: 'BSD').add_dependency(name: 'Library1')
        base_report.add_license(id: nil, name: 'WTFPL').add_dependency(name: 'Library2')

        head_report.add_license(id: nil, name: 'MIT').add_dependency(name: 'Library1')
        head_report.add_license(id: nil, name: 'Apache 2.0').add_dependency(name: 'Library3')
        head_report.add_license(id: nil, name: 'bsd').add_dependency(name: 'Library1')
      end

      it { expect(names_from(subject[:added])).to contain_exactly('Apache 2.0') }
      it { expect(names_from(subject[:unchanged])).to contain_exactly('MIT', 'BSD') }
      it { expect(names_from(subject[:removed])).to contain_exactly('WTFPL') }
    end

    context 'when diffing two v2 reports' do
      let(:base_report) { build(:license_scan_report, :version_2) }
      let(:head_report) { build(:license_scan_report, :version_2) }

      before do
        base_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'Library1')
        base_report.add_license(id: 'BSD-3-Clause', name: 'BSD').add_dependency(name: 'Library1')
        base_report.add_license(id: 'WTFPL', name: 'WTFPL').add_dependency(name: 'Library2')

        head_report.add_license(id: 'BSD-3-Clause', name: 'bsd').add_dependency(name: 'Library1')
        head_report.add_license(id: 'Apache-2.0', name: 'Apache 2.0').add_dependency(name: 'Library3')
        head_report.add_license(id: 'MIT', name: 'MIT License').add_dependency(name: 'Library1')
      end

      it { expect(names_from(subject[:added])).to contain_exactly('Apache 2.0') }
      it { expect(names_from(subject[:unchanged])).to contain_exactly('MIT', 'BSD') }
      it { expect(names_from(subject[:removed])).to contain_exactly('WTFPL') }
    end

    context 'when diffing a v1 report with a v2 report' do
      let(:base_report) { build(:license_scan_report, :version_1) }
      let(:head_report) { build(:license_scan_report, :version_2) }

      before do
        base_report.add_license(id: nil, name: 'MIT').add_dependency(name: 'Library1')
        base_report.add_license(id: nil, name: 'BSD').add_dependency(name: 'Library1')
        base_report.add_license(id: nil, name: 'WTFPL').add_dependency(name: 'Library2')

        head_report.add_license(id: 'BSD-3-Clause', name: 'bsd').add_dependency(name: 'Library1')
        head_report.add_license(id: 'Apache-2.0', name: 'Apache 2.0').add_dependency(name: 'Library3')
        head_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'Library1')
      end

      it { expect(names_from(subject[:added])).to contain_exactly('Apache 2.0') }
      it { expect(names_from(subject[:unchanged])).to contain_exactly('MIT', 'BSD') }
      it { expect(names_from(subject[:removed])).to contain_exactly('WTFPL') }
    end

    context 'when diffing a v2 report with a v1 report' do
      let(:base_report) { build(:license_scan_report, :version_2) }
      let(:head_report) { build(:license_scan_report, :version_1) }

      before do
        base_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'Library1')
        base_report.add_license(id: 'BSD-3-Clause', name: 'BSD').add_dependency(name: 'Library1')
        base_report.add_license(id: 'WTFPL', name: 'WTFPL').add_dependency(name: 'Library2')

        head_report.add_license(id: nil, name: 'bsd').add_dependency(name: 'Library1')
        head_report.add_license(id: nil, name: 'Apache 2.0').add_dependency(name: 'Library3')
        head_report.add_license(id: nil, name: 'MIT').add_dependency(name: 'Library1')
      end

      it { expect(names_from(subject[:added])).to contain_exactly('Apache 2.0') }
      it { expect(names_from(subject[:unchanged])).to contain_exactly('MIT', 'BSD') }
      it { expect(names_from(subject[:removed])).to contain_exactly('WTFPL') }
    end
  end

  describe '#empty?' do
    let(:completed_report) { build(:ci_reports_license_scanning_report, :report_1) }
    let(:empty_report) { build(:ci_reports_license_scanning_report) }

    it { expect(empty_report).to be_empty }
    it { expect(completed_report).not_to be_empty }
  end
end
