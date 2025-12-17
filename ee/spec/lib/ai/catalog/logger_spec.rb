# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Logger, feature_category: :workflow_catalog do
  subject(:logger) { described_class.new('/dev/null') }

  it_behaves_like 'a json logger', { 'feature_category' => 'workflow_catalog' }

  describe '#context' do
    let_it_be(:klass) { 'MyClass' }
    let_it_be(:item) { build_stubbed(:ai_catalog_item) }
    let_it_be(:version) { build_stubbed(:ai_catalog_item_version, item: item) }
    let_it_be(:consumer) { build_stubbed(:ai_catalog_item_consumer, item: item) }

    it 'sets multiple values at once' do
      logger.context(klass: klass, item: item, version: version, consumer: consumer)

      expect(logger.send(:klass)).to eq(klass)
      expect(logger.send(:item)).to eq(item)
      expect(logger.send(:version)).to eq(version)
      expect(logger.send(:consumer)).to eq(consumer)
    end

    it 'does not override values not provided in subsequent calls, but allows setting nils' do
      logger.context(klass: klass, item: item)
      logger.context(version: version, item: nil)

      expect(logger.send(:klass)).to eq(klass)
      expect(logger.send(:version)).to eq(version)
      expect(logger.send(:item)).to be_nil
    end

    it 'returns self for method chaining' do
      result = logger.context(klass: klass)

      expect(result).to be_a(described_class)
    end
  end

  describe '#default_attributes' do
    let_it_be(:item) { build_stubbed(:ai_catalog_item, id: 1, project_id: 2) }
    let_it_be(:version) do
      build_stubbed(:ai_catalog_item_version, id: 3, schema_version: 1, version: '1.2.0', item: item)
    end

    let_it_be(:consumer) do
      build_stubbed(:ai_catalog_item_consumer, id: 4, project_id: 5, group_id: 6, item: item,
        parent_item_consumer_id: 7, pinned_version_prefix: '2.2.2', service_account_id: 8)
    end

    subject(:default_attributes) { logger.default_attributes }

    it 'includes attributes when set via context' do
      logger.context(klass: 'MyClass', item: item, version: version, consumer: consumer)

      is_expected.to eq({
        feature_category: :workflow_catalog,
        class: 'MyClass',
        item_id: 1,
        item_project_id: 2,
        item_item_type: item.item_type,
        version_id: 3,
        version_schema_version: 1,
        version_version: '1.2.0',
        consumer_id: 4,
        consumer_project_id: 5,
        consumer_group_id: 6,
        consumer_parent_item_consumer_id: 7,
        consumer_service_account_id: 8,
        consumer_pinned_version_prefix: '2.2.2'
      })
    end

    it 'derives item from consumer when item not directly set' do
      logger.context(consumer: consumer)

      is_expected.to include(item_id: item.id)
    end

    it 'derives item from version when item not directly set' do
      logger.context(version: version)

      is_expected.to include(item_id: item.id)
    end

    it 'derives version from consumer when version not directly set' do
      allow(item).to receive(:resolve_version).and_return(version)

      logger.context(consumer: consumer)

      is_expected.to include(version_id: version.id)
    end
  end

  describe 'logging methods' do
    %i[info error debug warn].each do |level|
      describe "##{level}" do
        it 'merges options with message and calls super' do
          expect_next_instance_of(Gitlab::JsonLogger) do |instance|
            expect(instance).to receive(level).with(hash_including(
              message: 'Test message',
              extra: 'foo'
            ))
          end

          logger.send(level, message: 'Test message', extra: 'foo')
        end
      end
    end
  end
end
