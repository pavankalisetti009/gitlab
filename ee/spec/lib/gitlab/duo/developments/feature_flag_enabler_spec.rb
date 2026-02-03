# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::FeatureFlagEnabler, feature_category: :duo_chat do
  it 'enables feature flags by group ai framework' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::ai framework', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group ai coding' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::ai coding',
        name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group agent foundations' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::agent foundations', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group duo chat' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::duo chat', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group duo workflow' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::duo workflow', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'enables feature flags by group custom models' do
    expect(Feature::Definition).to receive(:definitions)
      .and_return({ test_f: Feature::Definition.new(nil, group: 'group::custom models', name: 'test_f') })
    expect(Feature).to receive(:enable).with(:test_f)

    described_class.execute
  end

  it 'excludes feature flags listed in EXCLUDED_FEATURE_FLAGS' do
    excluded_flag = described_class::EXCLUDED_FEATURE_FLAGS.first
    regular_flag = :regular_duo_flag

    expect(Feature::Definition).to receive(:definitions)
      .and_return({
        excluded_flag => Feature::Definition.new(nil, group: 'group::ai framework', name: excluded_flag.to_s),
        regular_flag => Feature::Definition.new(nil, group: 'group::ai framework', name: regular_flag.to_s)
      })

    expect(Feature).to receive(:enable).with(regular_flag)
    expect(Feature).not_to receive(:enable).with(excluded_flag)

    described_class.execute
  end
end
