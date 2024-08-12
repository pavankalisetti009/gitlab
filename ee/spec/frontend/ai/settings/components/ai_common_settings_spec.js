import { shallowMount } from '@vue/test-utils';
import { GlButton, GlAlert, GlForm } from '@gitlab/ui';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import DuoAvailabilityForm from 'ee/ai/settings/components/duo_availability_form.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

describe('AiCommonSettings', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AiCommonSettings, {
      propsData: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        areDuoSettingsLocked: false,
        ...props,
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);
  const findDuoAvailability = () => wrapper.findComponent(DuoAvailabilityForm);
  const findSaveButton = () => wrapper.findComponent(GlButton);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findForm = () => wrapper.findComponent(GlForm);

  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('passes props to settings-block component', () => {
    expect(findSettingsBlock().props()).toEqual({
      defaultExpanded: false,
      id: null,
      title: 'GitLab Duo features',
    });
  });

  it('renders GlForm component', () => {
    expect(findForm().exists()).toBe(true);
  });

  it('renders DuoAvailabilityForm component', () => {
    expect(findDuoAvailability().exists()).toBe(true);
  });

  it('disables save button when no changes are made', () => {
    expect(findSaveButton().props('disabled')).toBe(true);
  });

  it('enables save button when changes are made', async () => {
    await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
    expect(findSaveButton().props('disabled')).toBe(false);
  });

  it('does not show warning alert when form unchanged', () => {
    expect(findAlert().exists()).toBe(false);
  });

  it('does not show warning alert when availability is changed to default_on', async () => {
    await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_ON);
    expect(findAlert().exists()).toBe(false);
  });

  it('shows warning alert when availability is changed to default_off', async () => {
    await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
    expect(findAlert().exists()).toBe(true);
    expect(findAlert().text()).toContain(
      'When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
    );
  });

  it('shows warning alert when availability is changed to never_on', async () => {
    await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);
    expect(findAlert().exists()).toBe(true);
    expect(findAlert().text()).toContain(
      'When you save, GitLab Duo will be turned for all groups, subgroups, and projects.',
    );
  });

  it('emits submit event with correct data when form is submitted', async () => {
    await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
    findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });
    const emittedData = wrapper.emitted('submit')[0][0];
    expect(emittedData).toEqual({ duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF });
  });
});
