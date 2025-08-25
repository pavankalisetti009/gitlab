import { shallowMount } from '@vue/test-utils';
import { noop } from 'lodash';
import { GlModal, GlForm } from '@gitlab/ui';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';

describe('AiCatalogItemConsumerModal', () => {
  let wrapper;

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);

  const createWrapper = () => {
    wrapper = shallowMount(AiCatalogItemConsumerModal, {
      propsData: {
        flowName: 'My flow',
      },
    });
  };

  describe('when submitting the form', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits the submit event', () => {
      findForm().vm.$emit('submit', { preventDefault: noop });

      expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
        projectId: 'gid://gitlab/Project/1000000',
      });
    });
  });

  describe('when the modal emits the hidden event', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits the hide event', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('hide')).toHaveLength(1);
    });
  });
});
