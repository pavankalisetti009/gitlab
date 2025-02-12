# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'graphql customizable permission' do
  let(:permission_name) { :read_code }
  let(:permission_attrs) { { description: 'read code', milestone: '17.10' } }

  describe '.define_permission' do
    subject(:define_permission) { described_class.define_permission(permission_name, permission_attrs) }

    context 'for feature flagged permissions' do
      before do
        allow(::Feature::Definition).to receive(:get).with("custom_ability_#{permission_name}").and_return(true)
      end

      it 'is experimental' do
        expect(define_permission.deprecation_reason).to include('Experiment')
      end
    end

    context 'for non-feature flagged permissions' do
      it 'is not experimental' do
        expect(define_permission.deprecation_reason).to be_nil
      end
    end
  end
end
