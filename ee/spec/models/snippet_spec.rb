# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Snippet, feature_category: :source_code_management do
  describe '#repository_size_checker' do
    let(:checker) { subject.repository_size_checker }
    let(:current_size) { 60 }

    before do
      allow(subject.repository).to receive(:size).and_return(current_size)
    end

    context 'when snippet belongs to a project' do
      subject { build(:project_snippet, project: project) }

      let(:namespace) { build(:namespace) }
      let(:project) { build(:project, namespace: namespace) }

      include_examples 'size checker for snippet'
    end

    context 'when snippet without a project' do
      let(:namespace) { nil }

      include_examples 'size checker for snippet'
    end
  end

  describe '.by_repository_storage' do
    let_it_be(:snippet_in_default_storage) { create(:project_snippet, :repository) }
    let_it_be(:snippet_without_storage) { create(:project_snippet) }

    it 'filters snippet by repository storage name' do
      snippets = described_class.by_repository_storage("default")
      expect(snippets).to eq([snippet_in_default_storage])
    end
  end

  describe '.allowed_for_ip' do
    let_it_be(:current_ip) { '127.0.0.1' }
    let_it_be(:ip_restriction) { create(:ip_restriction, range: '192.168.0.0/24') }
    let_it_be(:snippet_with_ip_restriction) do
      create(:project_snippet, project: create(:project, group: ip_restriction.group))
    end

    let_it_be(:snippet_without_ip_restriction) { create(:project_snippet) }
    let_it_be(:personal_snippet) { create(:personal_snippet) }

    subject(:allowed_snippets) { described_class.allowed_for_ip(current_ip) }

    context 'when the current IP is allowed' do
      let(:current_ip) { '192.168.0.1' }

      it { is_expected.to match_array(described_class.all) }
    end

    context 'when the current IP is not allowed' do
      let(:current_ip) { '127.0.0.1' }

      it { is_expected.to contain_exactly(snippet_without_ip_restriction, personal_snippet) }
    end
  end
end
