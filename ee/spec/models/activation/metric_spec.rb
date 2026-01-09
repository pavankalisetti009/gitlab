# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Activation::Metric, feature_category: :onboarding do
  describe 'associations' do
    it { is_expected.to belong_to(:user).required(true) }
    it { is_expected.to belong_to(:namespace).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:metric) }

    describe 'uniqueness' do
      context 'when metric is scoped to user_id and namespace_id' do
        let(:metric) { create(:activation_metric) }

        it 'prevents duplicate metric for same user and namespace' do
          duplicate = build(:activation_metric, user: metric.user, namespace: metric.namespace)
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:metric]).to include('has already been taken')
        end

        it 'allows same metric for different user' do
          different_user = build(:activation_metric, namespace: metric.namespace)
          expect(different_user).to be_valid
        end

        it 'allows same metric for different namespace' do
          different_namespace = build(:activation_metric, user: metric.user)
          expect(different_namespace).to be_valid
        end
      end
    end
  end
end
