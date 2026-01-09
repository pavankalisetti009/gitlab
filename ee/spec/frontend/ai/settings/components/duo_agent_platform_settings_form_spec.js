import { shallowMount } from '@vue/test-utils';
import { GlCollapse, GlFormGroup, GlFormCheckbox } from '@gitlab/ui';
import DuoAgentPlatformSettingsForm from 'ee/ai/settings/components/duo_agent_platform_settings_form.vue';

describe('DuoAgentPlatformSettingsForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, slots = {}, provide = {} } = {}) => {
    wrapper = shallowMount(DuoAgentPlatformSettingsForm, {
      propsData: {
        enabled: true,
        ...props,
      },
      provide: {
        showDuoAgentPlatformEnablementSetting: true,
        ...provide,
      },
      slots,
      stubs: {
        GlFormCheckbox,
        GlFormGroup,
        GlCollapse,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findCollapse = () => wrapper.findComponent(GlCollapse);

  beforeEach(() => {
    createComponent();
  });

  describe('form group visibility', () => {
    it('renders the form group when showDuoAgentPlatformEnablementSetting is true', () => {
      createComponent({
        provide: {
          showDuoAgentPlatformEnablementSetting: true,
        },
      });

      expect(findFormGroup().exists()).toBe(true);
    });

    it('does not render the form group when showDuoAgentPlatformEnablementSetting is false', () => {
      createComponent({
        provide: {
          showDuoAgentPlatformEnablementSetting: false,
        },
      });

      expect(findFormGroup().exists()).toBe(false);
    });
  });

  it('renders the form group with label', () => {
    expect(findFormGroup().text()).toContain('GitLab Duo Agent Platform');
  });

  it('renders the checkbox with correct label', () => {
    expect(findFormCheckbox().exists()).toBe(true);
    expect(findFormCheckbox().text()).toContain(
      'Turn on GitLab Duo Chat (Agentic), agents, and flows',
    );
  });

  describe('checkbox behavior', () => {
    it('is checked when enabled prop is true', () => {
      createComponent({
        props: {
          enabled: true,
        },
      });

      expect(findFormCheckbox().props('checked')).toBe(true);
    });

    it('is unchecked when enabled prop is false', () => {
      createComponent({
        props: {
          enabled: false,
        },
      });

      expect(findFormCheckbox().props('checked')).toBe(false);
    });

    it('emits selected event with true when checkbox is checked', async () => {
      createComponent({
        props: {
          enabled: false,
        },
      });

      await findFormCheckbox().vm.$emit('input', true);

      expect(wrapper.emitted('selected')).toHaveLength(1);
      expect(wrapper.emitted('selected')[0]).toEqual([true]);
    });

    it('emits selected event with false when checkbox is unchecked', async () => {
      createComponent({
        props: {
          enabled: true,
        },
      });

      await findFormCheckbox().vm.$emit('input', false);

      expect(wrapper.emitted('selected')).toHaveLength(1);
      expect(wrapper.emitted('selected')[0]).toEqual([false]);
    });
  });

  describe('collapsible content', () => {
    it('expands content when enabled prop is true', () => {
      createComponent({ props: { enabled: true } });

      expect(findCollapse().props('visible')).toBe(true);
    });

    it('collapses content when enabled prop is false', () => {
      createComponent({ props: { enabled: false } });

      expect(findCollapse().props('visible')).toBe(false);
    });
  });
});
