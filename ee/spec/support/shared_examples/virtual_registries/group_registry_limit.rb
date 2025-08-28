# frozen_string_literal: true

RSpec.shared_examples 'virtual registries: group registry limit' do |registry_factory:|
  describe '#max_per_group' do
    let(:registry_2) { build(registry_factory, group: registry.group) }

    before do
      registry.save!
      stub_const("#{described_class}::MAX_REGISTRY_COUNT", 1)
    end

    it 'does not allow more than one registry per group' do
      expect(registry_2).to be_invalid
        .and have_attributes(errors: hash_including(group: ['1 registries is the maximum allowed per group.']))
    end
  end
end
