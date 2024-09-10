# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectSecurityExclusionsFinder, feature_category: :secret_detection do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:exclusions) do
    {
      inactive: create(:project_security_exclusion, project: project, active: false),
      raw_value: create(:project_security_exclusion, project: project),
      path: create(:project_security_exclusion, project: project, type: :path, value: 'spec/models/project_spec.rb'),
      regex: create(:project_security_exclusion, project: project, type: :regex_pattern, value: 'SK[0-9a-fA-F]{32}'),
      rule: create(:project_security_exclusion, project: project, type: :rule, value: 'gitlab_personal_access_token')
    }
  end

  let(:params) { {} }

  subject(:finder) { described_class.new(user, project: project, params: params) }

  shared_examples 'returns expected exclusions' do |expected_exclusions|
    it 'returns the correct exclusions' do
      expect(finder.execute).to contain_exactly(*expected_exclusions.map { |key| exclusions[key] })
    end
  end

  describe '#execute' do
    context 'with a role that can read security exclusions' do
      before_all { project.add_maintainer(user) }

      context 'without filters' do
        include_examples 'returns expected exclusions', [:rule, :regex, :raw_value, :path, :inactive]
      end

      context 'when filtering by security scanner' do
        let(:params) { { scanner: 'secret_push_protection' } }

        include_examples 'returns expected exclusions', [:rule, :regex, :raw_value, :path, :inactive]
      end

      context 'when filtering by exclusion type' do
        let(:params) { { type: 'rule' } }

        include_examples 'returns expected exclusions', [:rule]
      end

      context 'when filtering by exclusion status' do
        let(:params) { { active: true } }

        include_examples 'returns expected exclusions', [:rule, :regex, :raw_value, :path]
      end
    end

    context 'with a role that cannot read security exclusions' do
      before_all { project.add_reporter(user) }

      it 'returns no exclusions' do
        expect(finder.execute).to be_empty
      end
    end
  end
end
