import { GlButton, GlForm, GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import DuoAvailabilityForm from 'ee/ai/settings/components/duo_availability_form.vue';
import DuoExperimentBetaFeaturesForm from 'ee/ai/settings/components/duo_experiment_beta_features_form.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

describe('AiCommonSettings', () => {
  let wrapper;

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(AiCommonSettings, {
      propsData: {
        hasParentFormChanged: false,
        isGroup: false,
        ...props,
      },
      provide: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        experimentFeaturesEnabled: false,
        onGeneralSettingsPage: true,
        configurationSettingsPath: '/settings/gitlab_duo',
        ...provide,
      },
      stubs: {
        GlSprintf: {
          template: `
            <span>
              <slot name="link" v-bind="{ content: $attrs.message }">
              </slot>
            </span>
          `,
          components: {
            GlLink,
          },
        },
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findDuoAvailability = () => wrapper.findComponent(DuoAvailabilityForm);
  const findDuoExperimentBetaFeatures = () => wrapper.findComponent(DuoExperimentBetaFeaturesForm);
  const findSaveButton = () => wrapper.findComponent(GlButton);
  const findForm = () => wrapper.findComponent(GlForm);
  const findDuoSettingsWarningAlert = () => wrapper.findByTestId('duo-settings-show-warning-alert');
  const findMovedSettingsAlert = () => wrapper.findByTestId('duo-moved-settings-alert');
  const findMovedDescriptionText = () => wrapper.findComponent(GlSprintf);
  const findMovedSettingsLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  describe('when on general settings page', () => {
    it('renders SettingsBlock component', () => {
      expect(findSettingsBlock().exists()).toBe(true);
    });

    it('passes props to settings-block component', () => {
      expect(findSettingsBlock().props()).toEqual({
        defaultExpanded: false,
        id: null,
        title: 'GitLab Duo features',
      });
    });

    it('renders the moved settings alert', () => {
      expect(findMovedSettingsAlert().exists()).toBe(true);
      expect(findMovedSettingsAlert().props('title')).toBe('GitLab Duo settings have moved');
    });

    it('renders the alert with correct link based on group context', () => {
      createComponent({ isGroup: true });
      expect(findMovedDescriptionText().attributes('message')).toContain('Settings > GitLab Duo');
      expect(findMovedSettingsLink().attributes('href')).toBe('/settings/gitlab_duo');
    });

    it('includes the correct path text for non-group context', () => {
      createComponent({}, { configurationSettingsPath: '/admin/gitlab_duo' });
      expect(findMovedDescriptionText().attributes('message')).toContain('Admin Area > GitLab Duo');
      expect(findMovedSettingsLink().attributes('href')).toBe('/admin/gitlab_duo');
    });
  });

  describe('when not on general settings page', () => {
    beforeEach(() => {
      createComponent({}, { onGeneralSettingsPage: false });
    });

    it('renders PageHeading component', () => {
      expect(findPageHeading().exists()).toBe(true);
    });

    it('renders correct title in PageHeading', () => {
      expect(findPageHeading().props('heading')).toBe('Configuration');
    });

    it('renders correct subtitle in PageHeading', () => {
      expect(wrapper.findByTestId('configuration-page-subtitle').exists()).toBe(true);
    });

    it('renders GlForm component', () => {
      expect(findForm().exists()).toBe(true);
    });

    it('renders DuoAvailabilityForm component', () => {
      expect(findDuoAvailability().exists()).toBe(true);
    });

    it('renders DuoExperimentBetaFeaturesForm component', () => {
      expect(findDuoExperimentBetaFeatures().exists()).toBe(true);
    });

    it('disables save button when no changes are made', () => {
      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('enables save button when changes are made', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
      await findDuoExperimentBetaFeatures().vm.$emit('change', true);
      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('enables save button when parent form changes are made', () => {
      createComponent({ hasParentFormChanged: true }, { onGeneralSettingsPage: false });
      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('does not show warning alert when form unchanged', () => {
      expect(findDuoSettingsWarningAlert().exists()).toBe(false);
    });

    it('does not show warning alert when availability is changed to default_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_ON);
      expect(findDuoSettingsWarningAlert().exists()).toBe(false);
    });

    it('shows warning alert when availability is changed to default_off', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
      expect(findDuoSettingsWarningAlert().exists()).toBe(true);
      expect(findDuoSettingsWarningAlert().text()).toContain(
        'When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
      );
    });

    it('shows warning alert when availability is changed to never_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);
      expect(findDuoSettingsWarningAlert().exists()).toBe(true);
      expect(findDuoSettingsWarningAlert().text()).toContain(
        'When you save, GitLab Duo will be turned for all groups, subgroups, and projects.',
      );
    });

    it('emits submit event with correct data when form is submitted', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
      await findDuoExperimentBetaFeatures().vm.$emit('change', true);
      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });
      const emittedData = wrapper.emitted('submit')[0][0];
      expect(emittedData).toEqual({
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: true,
      });
    });
  });
});
