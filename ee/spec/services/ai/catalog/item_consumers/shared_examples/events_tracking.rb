# frozen_string_literal: true

RSpec.shared_examples_for 'ItemConsumers::EventsTracking' do
  let(:event_name) { 'create_ai_catalog_item_consumer' }
  let(:project) { build(:project) }
  let(:group) { build(:group) }
  let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, project:, group:) }

  it 'tracks an event with the given event name, user, project, namespace, and additional properties' do
    expect(subject).to receive(:track_internal_event).with(
      event_name,
      user: subject.send(:current_user), # Method may be private
      project: project,
      namespace: group,
      additional_properties: {
        label: item_consumer.enabled.to_s,
        property: item_consumer.locked.to_s
      }
    )

    subject.track_item_consumer_event(item_consumer, event_name)
  end

  context 'when passing in additional_attributes' do
    it 'overwrites the defaults' do
      expect(subject).to receive(:track_internal_event).with(
        anything,
        a_hash_including(additional_properties: { label: 1, property: 2 })
      )

      subject.track_item_consumer_event(item_consumer, event_name, { additional_properties: { label: 1, property: 2 } })
    end

    context 'when the additional_properties key is set to nil' do
      it 'does not pass in additional_properties' do
        expect(subject).to receive(:track_internal_event) do |_, hash|
          expect(hash).not_to have_key(:additional_properties)
        end

        subject.track_item_consumer_event(item_consumer, event_name, { additional_properties: nil })
      end
    end
  end
end
