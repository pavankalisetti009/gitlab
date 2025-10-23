# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::VerificationStateDefinition, feature_category: :geo_replication do
  using RSpec::Parameterized::TableSyntax

  include ::EE::GeoHelpers

  before_all do
    create_dummy_model_table
  end

  after(:all) do
    drop_dummy_model_table
  end

  let_it_be(:dummy_model_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = '_test_dummy_models'
      include Geo::VerificationStateDefinition
    end
  end

  let(:dummy_model) { dummy_model_class.new }

  describe '#verification_state_name_no_prefix' do
    where(:raw_state, :expected_result) do
      :verification_pending   | 'pending'
      :verification_started   | 'started'
      :verification_succeeded | 'succeeded'
      :verification_failed    | 'failed'
      :verification_disabled  | 'disabled'
    end

    with_them do
      it 'removes verification_ prefix from state name' do
        dummy_model.verification_state = ::Geo::VerificationState::VERIFICATION_STATE_VALUES[raw_state]

        expect(dummy_model.verification_state_name_no_prefix).to eq(expected_result)
      end
    end
  end

  def create_dummy_model_table
    ActiveRecord::Schema.define do
      create_table :_test_dummy_models, force: true do |t|
        t.binary :verification_checksum
        t.integer :verification_state
        t.datetime_with_timezone :verification_started_at
        t.datetime_with_timezone :verified_at
        t.datetime_with_timezone :verification_retry_at
        t.integer :verification_retry_count
        t.text :verification_failure
      end
    end
  end

  def drop_dummy_model_table
    ActiveRecord::Schema.define do
      drop_table :_test_dummy_models, force: true
    end
  end
end
