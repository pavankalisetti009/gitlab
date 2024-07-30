import { shallowMount } from '@vue/test-utils';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';

describe('AiCommonSettings', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AiCommonSettings, {
      propsData: {
        ...props,
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);

  it('renders the component', () => {
    createComponent();
    expect(wrapper.exists()).toBe(true);
  });

  it('passes props to settings-block component', () => {
    createComponent();
    expect(findSettingsBlock().props()).toEqual({
      defaultExpanded: false,
      id: null,
      title: 'GitLab Duo features',
    });
  });
});
