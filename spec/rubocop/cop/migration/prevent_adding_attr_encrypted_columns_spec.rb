# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../../rubocop/cop/migration/prevent_adding_attr_encrypted_columns'

RSpec.describe RuboCop::Cop::Migration::PreventAddingAttrEncryptedColumns, feature_category: :database do
  context 'when in migration' do
    before do
      allow(cop).to receive(:in_migration?).and_return(true)
    end

    context 'when `encrypted_*` columns are introduced in create_table' do
      it 'registers offenses' do
        expect_offense(<<~RUBY)
          class CreateAuditEventsInstanceAmazonS3Configurations < ActiveRecord::Migration[6.0]
            def change
              create_table :audit_events_instance_amazon_s3_configurations do |t|
                t.binary :encrypted_secret_access_key, null: false
                  ^^^^^^ Do not introduce `encrypted_secret_access_key` (`attr_encrypted` column), introduce a single `secret_access_key` column with type `:jsonb` instead.[...]
                t.binary :encrypted_secret_access_key_iv, null: false
                  ^^^^^^ Do not introduce `encrypted_secret_access_key_iv` (`attr_encrypted` column), introduce a single `secret_access_key` column with type `:jsonb` instead.[...]
              end
            end
          end
        RUBY
      end
    end

    described_class::ADD_COLUMN_METHODS.each do |add_column_method|
      context "when `encrypted_*` columns are introduced with `#{add_column_method}`" do
        it 'registers offenses' do
          expect_offense(<<~RUBY, add_column_method: add_column_method)
            class CreateAuditEventsInstanceAmazonS3Configurations < ActiveRecord::Migration[6.0]
              def change
                %{add_column_method}(:audit_events_instance_amazon_s3_configurations, :encrypted_secret_access_key, :binary)
                ^{add_column_method} Do not introduce `encrypted_secret_access_key` (`attr_encrypted` column), introduce a single `secret_access_key` column with type `:jsonb` instead.[...]
                %{add_column_method}(:audit_events_instance_amazon_s3_configurations, :encrypted_secret_access_key_iv, :binary)
                ^{add_column_method} Do not introduce `encrypted_secret_access_key_iv` (`attr_encrypted` column), introduce a single `secret_access_key` column with type `:jsonb` instead.[...]
              end
            end
          RUBY
        end

        context "and column name is a constant" do
          it 'registers offenses' do
            expect_offense(<<~RUBY, add_column_method: add_column_method)
              class CreateAuditEventsInstanceAmazonS3Configurations < ActiveRecord::Migration[6.0]
                COLUMN_NAME = :encrypted_secret_access_key

                def change
                  %{add_column_method}(:audit_events_instance_amazon_s3_configurations, COLUMN_NAME, :binary)
                  ^{add_column_method} Do not introduce `encrypted_secret_access_key` (`attr_encrypted` column), introduce a single `secret_access_key` column with type `:jsonb` instead.[...]
                end
              end
            RUBY
          end
        end
      end
    end

    context 'when no `encrypted_*` columns are introduced' do
      it 'registers no offense' do
        expect_no_offenses(<<~RUBY)
          class Users < ActiveRecord::Migration[6.0]
            def up
              create_table :users do |t|
                t.jsonb :my_secret_field, null: false
                t.timestamps_with_timezone null: true
              end

              add_column(:users, :not_a_string, :integer)
            end
          end
        RUBY
      end
    end

    context 'when no `encrypted_*` columns are introduced but constant is used as column name' do
      it 'registers no offense' do
        expect_no_offenses(<<~RUBY)
          class Users < ActiveRecord::Migration[6.0]
            COLUMN_NAME = :container_scanning_for_registry_enabled

            def up
              add_column TABLE_NAME, COLUMN_NAME, :boolean, null: false,
                default: false
            end

            def down
              remove_column TABLE_NAME, COLUMN_NAME
            end
          end
        RUBY
      end
    end

    context 'when the string data type is used for arrays' do
      it 'registers no offense' do
        expect_no_offenses(<<~RUBY)
          class TestStringArrays < ActiveRecord::Migration[6.0]
            def up
              create_table :test_string_arrays, id: false do |t|
                t.integer :test_id, null: false
                t.string :name, array: true, default: [], null: false
              end

              add_column :test_string_arrays, :email, :string, array: true
              add_column :test_string_arrays, :role, :string, default: [], array: true
              change_column_type_concurrently :test_string_arrays, :test_id, :string, array: true
            end
          end
        RUBY
      end
    end

    context 'when using down method' do
      it 'registers no offense' do
        expect_no_offenses(<<~RUBY)
          class Users < ActiveRecord::Migration[6.0]
            def up
              remove_column :audit_events_instance_amazon_s3_configurations, :encrypted_secret_access_key
              remove_column :audit_events_instance_amazon_s3_configurations, :encrypted_secret_access_key_iv

              drop_table :audit_events_instance_amazon_s3_configurations
            end

            def down
              create_table :audit_events_instance_amazon_s3_configurations, id: false do |t|
                t.integer :test_id, null: false
                t.string :name
              end

              add_column(:audit_events_instance_amazon_s3_configurations, :encrypted_secret_access_key, :binary)
              add_column(:audit_events_instance_amazon_s3_configurations, :encrypted_secret_access_key_iv, :binary)
            end
          end
        RUBY
      end
    end
  end

  context 'when outside of migration' do
    it 'registers no offense' do
      expect_no_offenses(<<~RUBY)
        class CreateAuditEventsInstanceAmazonS3Configurations < Gitlab::Database::Migration[2.2]
          def change
            create_table :audit_events_instance_amazon_s3_configurations do |t|
              t.binary :encrypted_secret_access_key, null: false
              t.binary :encrypted_secret_access_key_iv, null: false
            end
          end
        end
      RUBY
    end
  end
end
