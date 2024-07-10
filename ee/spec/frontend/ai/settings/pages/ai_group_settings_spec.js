import { shallowMount } from '@vue/test-utils';
import AiGroupSettings from 'ee/ai/settings/pages/ai_group_settings.vue';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';

let wrapper;

const createComponent = (props = {}) => {
  wrapper = shallowMount(AiGroupSettings, {
    propsData: {
      ...props,
    },
  });
};

const findCommonSettings = () => wrapper.findComponent(AiCommonSettings);

describe('AiGroupSettings', () => {
  describe('UI', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('passes props to the common component', () => {
      expect(findCommonSettings().props().largeTitle).toBe(false);
    });
  });
});
