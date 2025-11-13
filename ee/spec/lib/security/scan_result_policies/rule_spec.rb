# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::Rule, feature_category: :security_policy_management do
  describe '#type' do
    it 'returns the rule type' do
      rule = described_class.new({ type: 'scan_finding' })
      expect(rule.type).to eq('scan_finding')
    end
  end

  describe '#branches' do
    it 'returns the branches array' do
      rule = described_class.new({ branches: %w[main develop] })
      expect(rule.branches).to match_array(%w[main develop])
    end
  end

  describe '#branch_type' do
    it 'returns the branch_type' do
      rule = described_class.new({ branch_type: 'protected' })
      expect(rule.branch_type).to eq('protected')
    end
  end

  describe '#scanners' do
    it 'returns the scanners array' do
      rule = described_class.new({ scanners: %w[sast dependency_scanning] })
      expect(rule.scanners).to match_array(%w[sast dependency_scanning])
    end
  end

  describe '#vulnerabilities_allowed' do
    it 'returns the vulnerabilities_allowed value' do
      rule = described_class.new({ vulnerabilities_allowed: 5 })
      expect(rule.vulnerabilities_allowed).to eq(5)
    end
  end

  describe '#severity_levels' do
    it 'returns the severity_levels array' do
      rule = described_class.new({ severity_levels: %w[high critical] })
      expect(rule.severity_levels).to match_array(%w[high critical])
    end
  end

  describe '#vulnerability_states' do
    it 'returns the vulnerability_states array' do
      rule = described_class.new({ vulnerability_states: ['newly_detected'] })
      expect(rule.vulnerability_states).to match_array(['newly_detected'])
    end
  end

  describe '#commits' do
    it 'returns the commits array' do
      rule = described_class.new({ commits: %w[abc123 def456] })
      expect(rule.commits).to match_array(%w[abc123 def456])
    end
  end

  describe '#branch_exceptions' do
    context 'when branch_exceptions is present' do
      it 'returns the branch_exceptions array' do
        rule = described_class.new({ branch_exceptions: ['feature/*', 'hotfix/*'] })
        expect(rule.branch_exceptions).to match_array(['feature/*', 'hotfix/*'])
      end
    end

    context 'when branch_exceptions is not present' do
      it 'returns an empty array' do
        rule = described_class.new({})
        expect(rule.branch_exceptions).to be_empty
      end
    end
  end

  describe '#vulnerability_attributes' do
    context 'when vulnerability_attributes is present' do
      it 'returns the vulnerability_attributes hash' do
        rule = described_class.new({ vulnerability_attributes: { cve: 'CVE-2023-1234' } })
        expect(rule.vulnerability_attributes).to eq({ cve: 'CVE-2023-1234' })
      end
    end

    context 'when vulnerability_attributes is not present' do
      it 'returns an empty hash' do
        rule = described_class.new({})
        expect(rule.vulnerability_attributes).to be_empty
      end
    end
  end

  describe '#vulnerability_age' do
    context 'when vulnerability_age is present' do
      it 'returns the vulnerability_age hash' do
        rule = described_class.new({ vulnerability_age: { operator: 'greater_than', value: 30 } })
        expect(rule.vulnerability_age).to eq({ operator: 'greater_than', value: 30 })
      end
    end

    context 'when vulnerability_age is not present' do
      it 'returns an empty hash' do
        rule = described_class.new({})
        expect(rule.vulnerability_age).to be_empty
      end
    end
  end

  describe '#match_on_inclusion_license' do
    it 'returns the match_on_inclusion_license value' do
      rule = described_class.new({ match_on_inclusion_license: true })
      expect(rule.match_on_inclusion_license).to be true
    end
  end

  describe '#license_types' do
    context 'when license_types is present' do
      it 'returns the license_types array' do
        rule = described_class.new({ license_types: ['MIT', 'Apache-2.0'] })
        expect(rule.license_types).to match_array(['MIT', 'Apache-2.0'])
      end
    end

    context 'when license_types is not present' do
      it 'returns an empty array' do
        rule = described_class.new({})
        expect(rule.license_types).to be_empty
      end
    end
  end

  describe '#license_states' do
    context 'when license_states is present' do
      it 'returns the license_states array' do
        rule = described_class.new({ license_states: %w[detected newly_detected] })
        expect(rule.license_states).to match_array(%w[detected newly_detected])
      end
    end

    context 'when license_states is not present' do
      it 'returns an empty array' do
        rule = described_class.new({})
        expect(rule.license_states).to be_empty
      end
    end
  end

  describe '#licenses' do
    context 'when licenses is present' do
      let(:allowed_licenses) do
        {
          allowed: [
            {
              name: 'MIT License',
              packages: { excluding: { purls: ['pkg:gem/bundler@1.0.0'] } }
            }
          ]
        }
      end

      it 'returns the licenses hash' do
        rule = described_class.new(licenses: allowed_licenses)
        expect(rule.licenses).to eq(allowed_licenses)
      end
    end

    context 'when licenses is not present' do
      it 'returns an empty hash' do
        rule = described_class.new({})
        expect(rule.licenses).to be_empty
      end
    end
  end
end
