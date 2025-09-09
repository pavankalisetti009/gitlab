import { shallowMount } from '@vue/test-utils';
import { noop } from 'lodash';
import { GlForm, GlFormGroup, GlModal, GlSprintf } from '@gitlab/ui';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';
import { mockBaseAgent } from '../mock_data';

describe('AiCatalogItemConsumerModal', () => {
  let wrapper;

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);

  const createWrapper = () => {
    wrapper = shallowMount(AiCatalogItemConsumerModal, {
      propsData: {
        item: mockBaseAgent,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    createWrapper();
  });

  describe('component rendering', () => {
    it('renders modal and item name', () => {
      expect(findModal().props('title')).toBe('Add this agent to a project');
      expect(findModal().find('dt').text()).toBe('Selected agent');
      expect(findModal().find('dd').text()).toBe(mockBaseAgent.name);
    });

    it('renders project id input', () => {
      expect(findFormGroup().props('labelDescription')).toBe(
        'Select a project to which you want to add this agent.',
      );
    });
  });

  describe('when submitting the form', () => {
    it('emits the submit event', () => {
      findForm().vm.$emit('submit', { preventDefault: noop });

      expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
        projectId: 'gid://gitlab/Project/1000000',
      });
    });
  });

  describe('when the modal emits the hidden event', () => {
    it('emits the hide event', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('hide')).toHaveLength(1);
    });
  });
});
