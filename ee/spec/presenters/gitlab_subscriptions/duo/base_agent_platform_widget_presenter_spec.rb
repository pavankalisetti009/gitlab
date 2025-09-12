# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::BaseAgentPlatformWidgetPresenter, :aggregate_failures, feature_category: :activation do
  describe '#attributes' do
    let(:user) { build_stubbed(:user) }

    where(:method_name) do
      %i[
        action_path
        eligible?
        enabled_without_beta_features?
        fully_enabled?
        only_duo_default_off?
        enabled_without_core?
        contextual_attributes
      ]
    end

    with_them do
      it 'raises NoMethodError when abstract method is not implemented' do
        error_message = /This method must be implemented in a subclass/

        expect { presenter_without(method_name).attributes }.to raise_error(NoMethodError, error_message)
      end
    end

    context 'when not eligible' do
      let(:presenter) { ineligible_presenter }

      it 'returns empty hash' do
        expect(presenter.attributes).to eq({})
      end
    end

    context 'when eligible and fully enabled' do
      let(:presenter) { fully_enabled_presenter }

      it 'returns attributes with enabled state' do
        expected_attributes = {
          duoAgentWidgetProvide: {
            actionPath: '/test/action/path',
            stateProgression: [:enabled],
            initialState: :enabled,
            contextualAttributes: {}
          }
        }

        expect(presenter.attributes).to eq(expected_attributes)
      end
    end

    context 'when eligible and enabled without beta features' do
      let(:presenter) { enabled_without_beta_features_presenter }

      it 'returns attributes with enabled_without_beta_features state' do
        expected_attributes = {
          duoAgentWidgetProvide: {
            actionPath: '/test/action/path',
            stateProgression: [:enableFeaturePreview, :enabled],
            initialState: :enabled_without_beta_features,
            contextualAttributes: {}
          }
        }

        expect(presenter.attributes).to eq(expected_attributes)
      end
    end

    context 'when eligible and enabled without core' do
      let(:presenter) { enabled_without_core_presenter }

      it 'returns attributes with enabled_without_core state' do
        expected_attributes = {
          duoAgentWidgetProvide: {
            actionPath: '/test/action/path',
            stateProgression: [:enablePlatform, :enabled],
            initialState: :enabled_without_core,
            contextualAttributes: {}
          }
        }

        expect(presenter.attributes).to eq(expected_attributes)
      end
    end

    context 'when eligible and only duo default off' do
      let(:presenter) { only_duo_default_off_presenter }

      it 'returns attributes with only_duo_default_off state' do
        expected_attributes = {
          duoAgentWidgetProvide: {
            actionPath: '/test/action/path',
            stateProgression: [:enablePlatform, :enabled],
            initialState: :only_duo_default_off,
            contextualAttributes: {}
          }
        }

        expect(presenter.attributes).to eq(expected_attributes)
      end
    end

    context 'when eligible and disabled' do
      let(:presenter) { disabled_presenter }

      it 'returns attributes with disabled state' do
        expected_attributes = {
          duoAgentWidgetProvide: {
            actionPath: '/test/action/path',
            stateProgression: [:enablePlatform, :enableFeaturePreview, :enabled],
            initialState: :disabled,
            contextualAttributes: {}
          }
        }

        expect(presenter.attributes).to eq(expected_attributes)
      end
    end
  end

  private

  def presenter_without(method = nil)
    klass = stub_const('TestPresenter', Class.new(described_class))

    complete_methods = [
      :action_path, :eligible?, :enabled_without_beta_features?, :enabled_without_core?,
      :fully_enabled?, :only_duo_default_off?, :contextual_attributes
    ]

    complete_methods.each do |m|
      next if m == method

      klass.class_eval do
        define_method(m) do
          case m
          when :action_path then '/test/action/path'
          when :eligible? then true
          when :enabled_without_beta_features? then false
          when :fully_enabled? then false
          when :only_duo_default_off? then false
          when :enabled_without_core? then false
          when :contextual_attributes then {}
          end
        end
      end
    end

    presenter = klass.new(user)
    presenter.send(method) if method
    presenter
  end

  def create_presenter_class(
    eligible:, fully_enabled:, enabled_without_beta_features:, only_duo_default_off:, enabled_without_core:
  )
    Class.new(described_class) do
      define_method(:eligible?) { eligible }
      define_method(:fully_enabled?) { fully_enabled }
      define_method(:enabled_without_beta_features?) { enabled_without_beta_features }
      define_method(:only_duo_default_off?) { only_duo_default_off }
      define_method(:action_path) { '/test/action/path' }
      define_method(:enabled_without_core?) { enabled_without_core }
      define_method(:contextual_attributes) { {} }
    end
  end

  def ineligible_presenter
    create_presenter_class(
      eligible: false,
      fully_enabled: false,
      enabled_without_beta_features: false,
      only_duo_default_off: false,
      enabled_without_core: false
    ).new(user)
  end

  def fully_enabled_presenter
    create_presenter_class(
      eligible: true,
      fully_enabled: true,
      enabled_without_beta_features: false,
      only_duo_default_off: false,
      enabled_without_core: false
    ).new(user)
  end

  def enabled_without_beta_features_presenter
    create_presenter_class(
      eligible: true,
      fully_enabled: false,
      enabled_without_beta_features: true,
      only_duo_default_off: false,
      enabled_without_core: false
    ).new(user)
  end

  def enabled_without_core_presenter
    create_presenter_class(
      eligible: true,
      fully_enabled: false,
      enabled_without_beta_features: false,
      only_duo_default_off: false,
      enabled_without_core: true
    ).new(user)
  end

  def only_duo_default_off_presenter
    create_presenter_class(
      eligible: true,
      fully_enabled: false,
      enabled_without_beta_features: false,
      only_duo_default_off: true,
      enabled_without_core: false
    ).new(user)
  end

  def disabled_presenter
    create_presenter_class(
      eligible: true,
      fully_enabled: false,
      enabled_without_beta_features: false,
      only_duo_default_off: false,
      enabled_without_core: false
    ).new(user)
  end
end
