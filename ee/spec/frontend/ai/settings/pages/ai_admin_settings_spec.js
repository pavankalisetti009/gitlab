import { shallowMount } from '@vue/test-utils';
import AiAdminSettings from 'ee/ai/settings/pages/ai_admin_settings.vue';

let wrapper;

const createComponent = (props = {}) => {
  wrapper = shallowMount(AiAdminSettings, {
    propsData: {
      ...props,
    },
  });
};

describe('AiAdminSettings', () => {
  describe('UI', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });
  });
});
