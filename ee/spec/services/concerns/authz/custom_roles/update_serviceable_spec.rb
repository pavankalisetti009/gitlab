# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::CustomRoles::UpdateServiceable, feature_category: :permissions do
  subject(:klass) { Class.new(Object).include(described_class) }

  describe 'required_methods' do
    [:allowed?, :authorized_error, :role, :role_class, :params].each do |method_name|
      it "raises NotImplementedError for #{method_name}" do
        expect do
          klass.new.send(method_name)
        end.to raise_error NotImplementedError,
          "Classes including #{described_class} must implement #{method_name}"
      end

      context 'when the method is implemented' do
        before do
          klass.define_method(method_name) { true }
        end

        it "does not raise NotImplementedError" do
          expect do
            klass.new.send(method_name)
          end.not_to raise_error
        end
      end
    end
  end
end
