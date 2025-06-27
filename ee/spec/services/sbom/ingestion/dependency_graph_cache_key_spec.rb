# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::DependencyGraphCacheKey, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:sbom_report) { create(:ci_reports_sbom_report, num_components: 3) }

  subject(:cache_key_service) { described_class.new(project, sbom_report) }

  describe '#key' do
    let(:expected_cache_key) do
      components = sbom_report.components
        .sort_by(&:ref)
        .map { |c| c.ref.to_s + c.ancestors.reject(&:empty?).map { |a| a[:name] + a[:version] }.join }
        .join

      OpenSSL::Digest::SHA256.hexdigest(project.id.to_s + components)
    end

    it 'generates a cache key based on project ID and sorted components' do
      expect(cache_key_service.key).to eq(expected_cache_key)
    end

    it 'returns a string' do
      expect(cache_key_service.key).to be_a(String)
    end

    it 'returns a 64-character hexadecimal string (SHA256)' do
      expect(cache_key_service.key).to match(/\A[a-f0-9]{64}\z/)
    end

    context 'with memoization' do
      it 'memoizes the cache key' do
        first_call = cache_key_service.key
        second_call = cache_key_service.key

        expect(first_call).to eq(second_call)
        expect(cache_key_service.instance_variable_get(:@cache_key)).to eq(first_call)
      end

      it 'only calculates the cache key once' do
        expect(OpenSSL::Digest::SHA256).to receive(:hexdigest).once.and_call_original

        cache_key_service.key
        cache_key_service.key
      end
    end

    context 'with different projects' do
      let_it_be(:another_project) { create(:project) }
      let(:another_cache_key_service) { described_class.new(another_project, sbom_report) }

      it 'generates different cache keys for different projects' do
        expect(cache_key_service.key).not_to eq(another_cache_key_service.key)
      end
    end

    context 'with different SBOM reports' do
      let_it_be(:another_sbom_report) { create(:ci_reports_sbom_report, num_components: 2) }
      let(:another_cache_key_service) { described_class.new(project, another_sbom_report) }

      it 'generates different cache keys for different SBOM reports' do
        expect(cache_key_service.key).not_to eq(another_cache_key_service.key)
      end
    end

    context 'with identical inputs' do
      let(:duplicate_cache_key_service) { described_class.new(project, sbom_report) }

      it 'generates the same cache key for identical inputs' do
        expect(cache_key_service.key).to eq(duplicate_cache_key_service.key)
      end
    end

    context 'with components having dependencies' do
      let_it_be(:component_with_ancestors) do
        build(:ci_reports_sbom_component,
          ref: 'component-with-deps',
          name: 'test-component',
          version: '1.0.0',
          ancestors: [
            { name: 'parent1', version: '2.0.0' },
            { name: 'parent2', version: '3.0.0' }
          ])
      end

      let_it_be(:sbom_report_with_deps) do
        report = create(:ci_reports_sbom_report, num_components: 0)
        report.add_component(component_with_ancestors)
        report
      end

      let(:cache_key_service_with_deps) { described_class.new(project, sbom_report_with_deps) }

      it 'includes ancestor information in the cache key' do
        cache_key = cache_key_service_with_deps.key

        expect(cache_key).to be_a(String)
        expect(cache_key).to match(/\A[a-f0-9]{64}\z/)
      end

      it 'generates different cache keys when ancestors differ' do
        another_component = build(:ci_reports_sbom_component,
          ref: 'component-with-deps',
          name: 'test-component',
          version: '1.0.0')

        allow(another_component).to receive(:ancestors).and_return([
          { name: 'different-parent', version: '2.0.0' }
        ])

        another_report = create(:ci_reports_sbom_report, num_components: 0)
        another_report.add_component(another_component)
        another_service = described_class.new(project, another_report)

        expect(cache_key_service_with_deps.key).not_to eq(another_service.key)
      end
    end

    context 'with components having empty ancestors' do
      let_it_be(:component_with_empty_ancestors) do
        build(:ci_reports_sbom_component,
          ref: 'component-empty-deps',
          name: 'test-component',
          version: '1.0.0',
          ancestors: [
            {},
            { name: 'parent1', version: '2.0.0' },
            {}
          ])
      end

      let_it_be(:sbom_report_with_empty_deps) do
        report = create(:ci_reports_sbom_report, num_components: 0)
        report.add_component(component_with_empty_ancestors)
        report
      end

      let(:cache_key_service_with_empty_deps) { described_class.new(project, sbom_report_with_empty_deps) }

      it 'filters out empty ancestors when generating cache key' do
        cache_key = cache_key_service_with_empty_deps.key

        expect(cache_key).to be_a(String)
        expect(cache_key).to match(/\A[a-f0-9]{64}\z/)
      end
    end

    context 'with no components' do
      let_it_be(:empty_sbom_report) { create(:ci_reports_sbom_report, num_components: 0) }
      let(:empty_cache_key_service) { described_class.new(project, empty_sbom_report) }

      it 'generates a cache key for empty component list' do
        cache_key = empty_cache_key_service.key

        expect(cache_key).to be_a(String)
        expect(cache_key).to match(/\A[a-f0-9]{64}\z/)
      end

      it 'generates different cache key than reports with components' do
        expect(empty_cache_key_service.key).not_to eq(cache_key_service.key)
      end
    end

    context 'with components in different order' do
      let_it_be(:component1) do
        build(:ci_reports_sbom_component, ref: 'z-component', name: 'last-component', version: '1.0.0')
      end

      let_it_be(:component2) do
        build(:ci_reports_sbom_component, ref: 'a-component', name: 'first-component', version: '1.0.0')
      end

      let_it_be(:report1) do
        report = create(:ci_reports_sbom_report, num_components: 0)
        report.add_component(component1)
        report.add_component(component2)
        report
      end

      let_it_be(:report2) do
        report = create(:ci_reports_sbom_report, num_components: 0)
        report.add_component(component2)
        report.add_component(component1)
        report
      end

      it 'generates the same cache key regardless of component order in report' do
        service1 = described_class.new(project, report1)
        service2 = described_class.new(project, report2)

        expect(service1.key).to eq(service2.key)
      end
    end
  end
end
