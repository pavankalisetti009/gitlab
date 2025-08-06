# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Filters, feature_category: :global_search do
  describe '.by_substring' do
    it 'returns a substring filter with required pattern' do
      expect(described_class.by_substring(pattern: 'foo')).to eq({ substring: { pattern: 'foo' } })
    end

    it 'includes optional parameters if provided' do
      result = described_class.by_substring(pattern: 'foo', case_sensitive: true, file_name: 'bar', content: 'baz')
      expect(result).to eq({ substring: { pattern: 'foo', case_sensitive: true, file_name: 'bar', content: 'baz' } })
    end
  end

  describe '.by_traversal_ids' do
    it 'raises error if traversal_ids is empty' do
      expect { described_class.by_traversal_ids([]) }.to raise_error(ArgumentError, 'Traversal IDs cannot be empty')
    end

    it 'returns a traversal_ids filter with the given IDs as a prefix search' do
      expect(described_class.by_traversal_ids('123-456-')).to eq({ meta: { key: 'traversal_ids', value: '^123-456-' } })
    end
  end

  describe '.by_repo_ids' do
    it 'raises error if ids is not an array' do
      expect { described_class.by_repo_ids('foo') }.to raise_error(ArgumentError)
    end

    it 'returns repo_ids as integers' do
      expect(described_class.by_repo_ids(['1', 2])).to eq({ repo_ids: [1, 2] })
    end
  end

  describe '.by_regexp' do
    it 'returns a regexp filter with required regexp' do
      expect(described_class.by_regexp(regexp: 'foo')).to eq({ regexp: { regexp: 'foo' } })
    end

    it 'includes optional parameters if provided' do
      result = described_class.by_regexp(regexp: 'foo', case_sensitive: false, file_name: 'bar', content: 'baz')
      expect(result).to eq({ regexp: { regexp: 'foo', case_sensitive: false, file_name: 'bar', content: 'baz' } })
    end
  end

  describe '.and_filters' do
    it 'returns an and filter with children' do
      expect(described_class.and_filters({ a: 1 }, { b: 2 })).to eq({ and: { children: [{ a: 1 }, { b: 2 }] } })
    end
  end

  describe '.or_filters' do
    it 'returns an or filter with children' do
      expect(described_class.or_filters({ a: 1 }, { b: 2 })).to eq({ or: { children: [{ a: 1 }, { b: 2 }] } })
    end
  end

  describe '.not_filter' do
    it 'returns a not filter with child' do
      expect(described_class.not_filter({ a: 1 })).to eq({ not: { child: { a: 1 } } })
    end
  end

  describe '.by_symbol' do
    it 'returns a symbol filter' do
      expect(described_class.by_symbol('foo')).to eq({ symbol: { expr: 'foo' } })
    end
  end

  describe '.by_meta' do
    it 'returns a meta filter' do
      expect(described_class.by_meta(key: 'foo', value: 'bar')).to eq({ meta: { key: 'foo', value: 'bar' } })
    end
  end

  describe '.by_query_string' do
    it 'returns a query_string filter' do
      expect(described_class.by_query_string('foo')).to eq({ query_string: { query: 'foo' } })
    end
  end

  describe '.by_project_id' do
    it 'raises error if id is nil' do
      expect { described_class.by_project_id(nil) }.to raise_error(ArgumentError, 'Project ID cannot be nil')
    end

    it 'returns a meta filter for project_id with correct regexp' do
      expect(described_class.by_project_id(123)).to eq({ meta: { key: 'project_id', value: '^123$' } })
    end
  end

  describe '.by_project_ids' do
    it 'returns an or filter of project_id meta filters' do
      expect(described_class.by_project_ids([1, 2])).to eq(
        described_class.or_filters(
          described_class.by_project_id(1),
          described_class.by_project_id(2)
        )
      )
    end

    it 'raises error if ids is empty' do
      expect { described_class.by_project_ids([]) }.to raise_error(ArgumentError, 'Project IDs cannot be empty')
    end
  end
end
