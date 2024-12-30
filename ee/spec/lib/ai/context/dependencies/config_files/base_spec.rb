# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::Base, feature_category: :code_suggestions do
  let(:config_file_class) { ConfigFileClass }

  before do
    stub_const('ConfigFileClass',
      Class.new(described_class) do
        def self.file_name_glob
          'test.json'
        end

        def self.lang_name
          'Go'
        end

        def extract_libs
          parsed = Gitlab::Json.parse(content)
          libs = dig_in(parsed, 'parent_node', 'child_node')
          libs.try(:map) { |hash| self.class::Lib.new(**hash) }
        rescue JSON::ParserError
          error('content is not valid JSON')
          nil
        end
      end
    )
  end

  it 'defines the expected interface for child classes' do
    blob = instance_double('Gitlab::Git::Blob', path: 'path/to/configfile', data: 'content')

    expect { described_class.file_name_glob }.to raise_error(NotImplementedError)
    expect { described_class.lang_name }.to raise_error(NotImplementedError)
    expect { described_class.new(blob).parse! }.to raise_error(NotImplementedError)
    expect(described_class.supports_multiple_files?).to eq(false)
  end

  it 'returns the expected language value' do
    expect(config_file_class.lang).to eq('go')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      Gitlab::Json.dump({
        'parent_node' => { 'child_node' => [
          { name: ' lib1 ' },
          { name: 'lib2', version: '2.1.0 ' },
          { name: '' },
          { name: nil },
          { name: 'lib3', version: '' },
          { name: 'lib4', version: nil },
          { name: 'lib5', version: 123 },
          { name: 'lib6', version: 1.0 }
        ] }
      })
    end

    let(:expected_formatted_lib_names) { ['lib1', 'lib2 (2.1.0)', 'lib3', 'lib4', 'lib5 (123)', 'lib6 (1.0)'] }
  end

  context 'when a dependency name contains an invalid byte sequence' do
    it_behaves_like 'parsing a valid dependency config file' do
      let(:invalid_byte_sequence) { [0xFE, 0x00, 0x00, 0x00].pack('C*') }
      let(:config_file_content) do
        <<~JSON
          {
            "parent_node": {
              "child_node": [
                { "name": "#{invalid_byte_sequence}lib1", "version": "1.0" },
                { "name": "lib2", "version": "2.0" }
              ]
            }
          }
        JSON
      end

      let(:expected_formatted_lib_names) { ['lib1 (1.0)', 'lib2 (2.0)'] }
    end
  end

  it_behaves_like 'parsing an invalid dependency config file' do
    let(:expected_error_message) { 'content is not valid JSON' }
  end

  context 'when no dependencies are extracted' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) { '{}' }
    end
  end

  context 'when the content has an unexpected node' do
    where(:content) do
      [
        [{ 'parent_node' => [] }],
        [{ 'parent_node' => 123 }],
        [123],
        [nil]
      ]
    end

    with_them do
      it_behaves_like 'parsing an invalid dependency config file' do
        let(:invalid_config_file_content) { Gitlab::Json.dump(content) }
        let(:expected_error_message) { 'encountered unexpected node' }
      end
    end
  end

  context 'when the content is empty' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) { '' }
      let(:expected_error_message) { 'file empty' }
    end
  end

  context 'when a dependency name is an array' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) do
        Gitlab::Json.dump({
          'parent_node' => { 'child_node' => [
            { name: ['lib1'], version: '1.0' },
            { name: 'lib2', version: '' }
          ] }
        })
      end

      let(:expected_error_message) { 'unexpected dependency name type `Array`' }
    end
  end

  context 'when a dependency version is an array' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) do
        Gitlab::Json.dump({
          'parent_node' => { 'child_node' => [
            { name: 'lib1', version: ['1.0'] },
            { name: 'lib2', version: '' }
          ] }
        })
      end

      let(:expected_error_message) { 'unexpected dependency version type `Array`' }
    end
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
        expect(config_file_class.matches?(path)).to eq(matches)
      end
    end
  end

  describe '.matching_paths' do
    let(:paths) { ['other.rb', 'dir/test.json', 'test.txt', 'test.json', 'README.md'] }

    subject(:matching_paths) { config_file_class.matching_paths(paths) }

    it 'returns the first matching path' do
      expect(matching_paths).to contain_exactly('dir/test.json')
    end

    context 'when multiple files are supported' do
      before do
        stub_const('ConfigFileClass',
          Class.new(described_class) do
            def self.file_name_glob
              'test.json'
            end

            def self.supports_multiple_files?
              true
            end
          end
        )
      end

      it 'returns all matching paths' do
        expect(matching_paths).to contain_exactly('dir/test.json', 'test.json')
      end
    end
  end
end
