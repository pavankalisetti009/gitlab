# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UrlHelpers, feature_category: :shared do
  using RSpec::Parameterized::TableSyntax

  describe '.normalized_base_url' do
    where(:url, :value) do
      'http://' | nil
      'ssh://foo:bar@example.com' | 'ssh://example.com'
      'http://foo:bar@example.com:3000/dir' | 'http://example.com:3000'
      'http://foo:bar@example.com/dir' | 'http://example.com'
    end

    with_them do
      it { expect(described_class.normalized_base_url(url)).to eq(value) }
    end

    context 'when `always_port` is true' do
      where(:url, :value) do
        'ssh://foo:bar@example.com' | 'ssh://example.com:22'
        'http://foo:bar@example.com:3000/dir' | 'http://example.com:3000'
        'http://foo:bar@example.com/dir' | 'http://example.com:80'
      end

      with_them do
        it { expect(described_class.normalized_base_url(url, always_port: true)).to eq(value) }
      end
    end
  end
end
