# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFileParser, feature_category: :code_suggestions do
  let(:config_file_parser) { described_class.new(project) }

  describe '#extract_config_files' do
    subject(:extract_config_files) { config_file_parser.extract_config_files }

    context 'when the repository does not contain a dependency config file' do
      let_it_be(:project) do
        create(:project, :custom_repo, files:
          {
            'a.txt' => 'foo',
            'dir1/b.rb' => 'bar'
          })
      end

      it 'returns an empty array' do
        expect(extract_config_files).to eq([])
      end
    end

    context 'when the repository contains dependency config files' do
      let_it_be(:project) do
        create(:project, :custom_repo, files:
          {
            'a.txt' => 'foo',
            'pom.xml' => '', # Only one of the two pom.xml files is processed
            'dir1/pom.xml' => '',
            'dir1/dir2/go.mod' => # Valid go.mod file
              <<~CONTENT,
                require abc.org/mylib v1.3.0
                require golang.org/x/mod v0.5.0
                require github.com/pmezard/go-difflib v1.0.0 // indirect
              CONTENT
            'dir1/dir2/dir3/Gemfile.lock' => # Valid Gemfile.lock but path is too deep
              <<~CONTENT
                GEM
                  remote: https://rubygems.org/
                  specs:
                    bcrypt (3.1.20)
              CONTENT
          })
      end

      it 'returns config file objects up to MAX_DEPTH with the expected attributes' do
        expect(config_files_array).to contain_exactly(
          {
            lang: 'java',
            valid: false,
            error_message: 'Error(s) while parsing file `dir1/pom.xml`: file empty',
            payload: nil
          },
          {
            lang: 'go',
            valid: true,
            error_message: nil,
            payload: a_hash_including(libs: [{ name: 'abc.org/mylib (1.3.0)' }, { name: 'golang.org/x/mod (0.5.0)' }])
          }
        )
      end

      context 'with a config file that supports multiple languages' do
        let_it_be(:project) do
          create(:project, :custom_repo, files:
            {
              'dir1/dir2/conanfile.txt' =>
                <<~CONTENT
                  [requires]
                  libiconv/1.17
                  poco/[>1.0,<1.9]
                CONTENT
            })
        end

        it 'returns a config file object for each supported language' do
          expect(config_files_array).to contain_exactly(
            {
              lang: 'c',
              valid: true,
              error_message: nil,
              payload: a_hash_including(libs: [{ name: 'libiconv (1.17)' }, { name: 'poco (>1.0,<1.9)' }])
            },
            {
              lang: 'cpp',
              valid: true,
              error_message: nil,
              payload: a_hash_including(libs: [{ name: 'libiconv (1.17)' }, { name: 'poco (>1.0,<1.9)' }])
            }
          )
        end
      end
    end
  end

  private

  def config_files_array
    extract_config_files.map do |config_file|
      {
        lang: config_file.class.lang,
        valid: config_file.valid?,
        error_message: config_file.error_message,
        payload: config_file.payload
      }
    end
  end
end
