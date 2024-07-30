import { shallowMount } from '@vue/test-utils';
import AiGroupSettings from 'ee/ai/settings/pages/ai_group_settings.vue';

let wrapper;

const createComponent = (props = {}) => {
  wrapper = shallowMount(AiGroupSettings, {
    propsData: {
      ...props,
    },
  });
};

describe('AiGroupSettings', () => {
  describe('UI', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });
  });
});
