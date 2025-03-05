# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../rubocop/cop/attr_encrypted'

RSpec.describe RuboCop::Cop::AttrEncrypted, feature_category: :shared do
  it 'does not raise an offense if not using attr_encrypted' do
    expect_no_offenses('encrypts :value')
  end

  it 'raises an offense when using attr_encrypted' do
    expect_offense(<<~RUBY)
      class Dummy < ApplicationRecord
        attr_encrypted :value,
        ^^^^^^^^^^^^^^^^^^^^^^ Do not use `attr_encrypted` to encrypt a column, as it's deprecated. Use `encrypts` which takes advantage of Active Record Encryption: https://docs.gitlab.com/development/migration_style_guide/#encrypted-attributes
          mode: :per_attribute_iv_and_salt,
          insecure_mode: true,
          key: Settings.attr_encrypted_db_key_base,
          algorithm: 'aes-256-cbc'
      end
    RUBY
  end
end
