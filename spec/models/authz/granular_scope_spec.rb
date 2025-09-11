# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Authz::GranularScope, feature_category: :permissions do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'validations' do
    describe 'permissions' do
      using RSpec::Parameterized::TableSyntax

      where(:permissions, :valid) do
        nil              | false
        'create_issue'   | false
        []               | false
        %w[xxx]          | false
        %w[create_issue] | true
      end

      with_them do
        subject { build(:granular_scope, permissions:).valid? }

        it { is_expected.to eq(valid) }
      end
    end
  end

  describe '.permitted_for_boundary?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:boundary) { Authz::Boundary.for(project) }
    let_it_be(:token_permissions) { ::Authz::Permission.all.keys.take(2) }
    let_it_be(:required_permissions) { token_permissions.first }

    subject { described_class.permitted_for_boundary?(boundary, required_permissions) }

    context 'when a scope exists for a boundary' do
      before do
        create(:granular_scope, namespace: boundary.namespace, permissions: token_permissions)
      end

      it { is_expected.to be true }

      context 'when the scope does not include the required permissions' do
        let_it_be(:required_permissions) { :not_allowed_permission }

        it { is_expected.to be false }
      end
    end

    context 'when a scope does not exist for a boundary' do
      it { is_expected.to be false }
    end
  end

  describe '.token_permissions' do
    let_it_be(:project) { create(:project) }
    let_it_be(:boundary) { Authz::Boundary.for(project) }
    let_it_be(:token_permissions) { ::Authz::Permission.all.keys.take(2) }

    subject { described_class.token_permissions(boundary) }

    context 'when a scope exists for a boundary' do
      before do
        create(:granular_scope, namespace: boundary.namespace, permissions: token_permissions)
      end

      it { is_expected.to eq token_permissions }
    end

    context 'when a scope does not exist for a boundary' do
      it { is_expected.to eq [] }
    end
  end
end
