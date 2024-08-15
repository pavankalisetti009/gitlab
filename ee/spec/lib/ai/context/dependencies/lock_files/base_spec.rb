# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::LockFiles::Base, feature_category: :code_suggestions do
  let(:lock_file_class) do
    Class.new(described_class) do
      def self.file_name_glob
        'test.json'
      end

      def self.lang_name
        'Go'
      end

      def extract_libs
        parsed = Gitlab::Json.parse(content)
        parsed['test_libs'].map { |hash| self.class::Lib.new(**hash) }
      rescue JSON::ParserError
        error('content is not a valid JSON')
        nil
      end
    end
  end

  it 'defines the expected interface for child classes' do
    blob = instance_double('Gitlab::Git::Blob', path: 'path/to/lockfile', data: 'content')

    expect { described_class.file_name_glob }.to raise_error(NotImplementedError)
    expect { described_class.lang_name }.to raise_error(NotImplementedError)
    expect { described_class.new(blob).parse! }.to raise_error(NotImplementedError)
  end

  it 'returns the expected language value' do
    expect(lock_file_class.lang).to eq('go')
  end

  it_behaves_like 'parsing a lock file' do
    let(:lock_file_content) do
      Gitlab::Json.dump({
        'test_libs' => [
          { name: 'lib1' },
          { name: 'lib2', version: '2.1.0' }
        ]
      })
    end

    let(:expected_formatted_lib_names) { ['lib1', 'lib2 (2.1.0)'] }
    let(:expected_parsing_error_message) { 'content is not a valid JSON' }
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'test.json'             | true
      'dir/test.json'         | true
      'dir/subdir/test.json'  | true
      'dir/test'              | false
      'xtest.json'            | false
      'test.jso'              | false
      'test'                  | false
      'unknown'               | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(lock_file_class.matches?(path)).to eq(matches)
      end
    end
  end
end
