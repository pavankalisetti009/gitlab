# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::PythonPoetryLock, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('python')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~TOML
        [[package]]
        name = "anthropic"
        version = "0.28.1"
        description = "The official Python library for the anthropic API"
        optional = false
        python-versions = ">=3.7"
        files = [
            {file = "anthropic-0.28.1-py3-none-any.whl", hash = "sha256:c4773ae2b42951a6b747bed328b0d03fa412938c95c3a8b9dce70d69badb710b"},
            {file = "anthropic-0.28.1.tar.gz", hash = "sha256:e3a6d595bde241141bdc685edc393903ec95c7fa378013a71186cfb8f32b1793"},
        ]

        [package.dependencies]
        anyio = ">=3.5.0,<5"
        distro = ">=1.7.0,<2"
        httpx = ">=0.23.0,<1"
        jiter = ">=0.4.0,<1"
        pydantic = ">=1.9.0,<3"
        sniffio = "*"
        tokenizers = ">=0.13.0"
        typing-extensions = ">=4.7,<5"

        [package.extras]
        bedrock = ["boto3 (>=1.28.57)", "botocore (>=1.31.57)"]
        vertex = ["google-auth (>=2,<3)"]

        [[package]]
        name = "anyio"
        version = "4.4.0"
        description = "High level compatibility layer for multiple asynchronous event loop implementations"
        optional = false
        python-versions = ">=3.8"
        files = [
            {file = "anyio-4.4.0-py3-none-any.whl", hash = "sha256:c1b2d8f46a8a812513012e1107cb0e68c17159a7a594208005a57dc776e1bdc7"},
            {file = "anyio-4.4.0.tar.gz", hash = "sha256:5aadc6a1bbb7cdb0bede386cac5e2940f5e2ff3aa20277e991cf028e0585ce94"},
        ]

        [package.dependencies]
        idna = ">=2.8"
        sniffio = ">=1.1"

        [package.extras]
        doc = ["Sphinx (>=7)", "packaging", "sphinx-autodoc-typehints (>=1.2.0)", "sphinx-rtd-theme"]
        test = ["anyio[trio]", "coverage[toml] (>=7)", "exceptiongroup (>=1.2.0)", "hypothesis (>=4.0)", "psutil (>=5.9)", "pytest (>=7.0)", "pytest-mock (>=3.6.1)", "trustme", "uvloop (>=0.17)"]
        trio = ["trio (>=0.23)"]
      TOML
    end

    let(:expected_formatted_lib_names) { ['anthropic (0.28.1)', 'anyio (4.4.0)'] }
  end

  context 'when config file content is an array' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) { '[]' }
      let(:expected_parsing_error_message) { 'content is not valid TOML' }
    end
  end

  it_behaves_like 'parsing an invalid dependency config file' do
    let(:expected_parsing_error_message) { 'content is not valid TOML' }
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'poetry.lock'             | true
      'dir/poetry.lock'         | true
      'dir/subdir/poetry.lock'  | true
      'dir/poetry.loc'          | false
      'poetry_lock'             | false
      'Poetry.lock'             | false
      'pyproject.toml'          | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
