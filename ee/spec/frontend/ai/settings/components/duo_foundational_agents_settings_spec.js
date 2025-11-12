import { nextTick } from 'vue';
import { GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoFoundationalAgentsSettings from 'ee/ai/settings/components/duo_foundational_agents_settings.vue';

describe('DuoFoundationalAgentsSettings', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DuoFoundationalAgentsSettings, {
      propsData: {
        enabled: true,
        ...props,
      },
    });
  };

  const findOnByDefaultRadio = () => wrapper.findAllComponents(GlFormRadio).at(0);
  const findOffByDefaultRadio = () => wrapper.findAllComponents(GlFormRadio).at(1);
  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);

  beforeEach(() => {
    createComponent();
  });

  it('selects "On by default" when enabledByDefault is true', () => {
    expect(findFormRadioGroup().attributes('checked')).toBe('true');
  });

  it('emits change event when enabled radio button is selected', async () => {
    findOnByDefaultRadio().vm.$emit('change', true);
    await nextTick();

    expect(wrapper.emitted('change')).toHaveLength(1);
    expect(wrapper.emitted('change')).toEqual([[true]]);
  });

  it('emits change event when disabled radio button is selected', async () => {
    findOffByDefaultRadio().vm.$emit('change', false);
    await nextTick();

    expect(wrapper.emitted('change')).toHaveLength(1);
    expect(wrapper.emitted('change')).toEqual([[false]]);
  });
});
