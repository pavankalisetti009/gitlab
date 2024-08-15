# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::LockFiles::RubyGems, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('ruby')
  end

  it_behaves_like 'parsing a lock file' do
    let(:lock_file_content) do
      <<~CONTENT
        GEM
          remote: https://rubygems.org/
          specs:
            bcrypt (3.1.20)
            logger (1.5.3)

        PLATFORMS
          ruby

        DEPENDENCIES
          bcrypt (~> 3.1, >= 3.1.14)
          logger (~> 1.5.3)

        BUNDLED WITH
          2.5.16
      CONTENT
    end

    let(:expected_formatted_lib_names) { ['bcrypt (3.1.20)', 'logger (1.5.3)'] }
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'Gemfile.lock'             | true
      'dir/Gemfile.lock'         | true
      'dir/subdir/Gemfile.lock'  | true
      'dir/Gemfile'              | false
      'xGemfile.lock'            | false
      'gemfile.lock'             | false
      'Gemfile_lock'             | false
      'Gemfile.loc'              | false
      'Gemfile'                  | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
