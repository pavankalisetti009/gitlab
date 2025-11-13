import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormGroup, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import DuoSastFpDetectionSettings from 'ee/ai/settings/components/duo_sast_fp_detection_settings.vue';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';

describe('DuoSastFpDetectionSettings', () => {
  let wrapper;
  const defaultProvide = {
    isGroupSettings: false,
    duoSastFpDetectionCascadingSettings: {
      lockedByAncestor: false,
      lockedByApplicationSetting: false,
    },
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findAvailabilityCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findLockIcon = () => wrapper.findComponent(GlIcon);
  const findLockButton = () =>
    wrapper.find('[data-testid="duo-sast-fp-detection-checkbox-locked"]');
  const findCascadingLock = () => wrapper.findComponent(CascadingLockIcon);

  const createWrapper = (props = {}, provide = {}) => {
    return shallowMount(DuoSastFpDetectionSettings, {
      propsData: {
        disabledCheckbox: false,
        duoSastFpDetectionAvailability: false,
        ...props,
      },
      provide: {
        ...defaultProvide,
        glFeatures: {
          aiExperimentSastFpDetection: true,
        },
        ...provide,
      },
      directives: {
        tooltip: GlTooltipDirective,
      },
      stubs: {
        GlFormCheckbox,
        GlFormGroup,
        GlIcon,
      },
    });
  };

  describe('feature flag behavior', () => {
    describe('when aiExperimentSastFpDetection feature flag is enabled', () => {
      beforeEach(() => {
        wrapper = createWrapper({}, { glFeatures: { aiExperimentSastFpDetection: true } });
      });

      it('renders the component', () => {
        expect(wrapper.exists()).toBe(true);
        expect(findFormGroup().exists()).toBe(true);
      });
    });

    describe('when aiExperimentSastFpDetection feature flag is disabled', () => {
      beforeEach(() => {
        wrapper = createWrapper({}, { glFeatures: { aiExperimentSastFpDetection: false } });
      });

      it('does not render the component', () => {
        expect(wrapper.find('div').exists()).toBe(false);
        expect(findFormGroup().exists()).toBe(false);
        expect(findAvailabilityCheckbox().exists()).toBe(false);
      });
    });
  });

  describe('component rendering', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('renders the form group with correct label', () => {
      expect(findFormGroup().exists()).toBe(true);
      expect(findFormGroup().attributes('label')).toBe('SAST False Positive Detection');
    });

    it('renders the checkbox with correct label', () => {
      expect(findAvailabilityCheckbox().exists()).toBe(true);
      expect(wrapper.find('#duo-sast-fp-detection-checkbox-label').text()).toBe(
        'Use Duo SAST False Positive Detection',
      );
    });

    it('sets initial checkbox state based on duoSastFpDetectionAvailability prop', () => {
      expect(findAvailabilityCheckbox().props('checked')).toBe(false);
    });

    it('does not render the cascading lock', () => {
      expect(findCascadingLock().exists()).toBe(false);
    });
  });

  describe('when duoSastFpDetectionAvailability is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({ duoSastFpDetectionAvailability: true });
    });

    it('sets checkbox as checked', () => {
      expect(findAvailabilityCheckbox().props('checked')).toBe(true);
    });
  });

  describe('when disabledCheckbox is false', () => {
    beforeEach(() => {
      wrapper = createWrapper({ disabledCheckbox: false });
    });

    it('enables the checkbox', () => {
      expect(findAvailabilityCheckbox().attributes('disabled')).toBe(undefined);
    });

    it('does not show lock icon', () => {
      expect(findLockButton().exists()).toBe(false);
    });
  });

  describe('when disabledCheckbox is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({ disabledCheckbox: true });
    });

    it('disables the checkbox', () => {
      expect(findAvailabilityCheckbox().props('disabled')).toBe(true);
    });

    it('shows lock icon with tooltip', () => {
      expect(findLockButton().exists()).toBe(true);
      expect(findLockIcon().exists()).toBe(true);
      expect(findLockIcon().props('name')).toBe('lock');
    });
  });

  describe('when duoSastFpDetectionCascadingSettings.lockedByApplicationSetting is true', () => {
    beforeEach(() => {
      wrapper = createWrapper(
        {},
        {
          duoSastFpDetectionCascadingSettings: {
            lockedByAncestor: false,
            lockedByApplicationSetting: true,
          },
        },
      );
    });

    it('shows cascading lock icon', () => {
      expect(findCascadingLock().exists()).toBe(true);
    });

    it('disables the checkbox', () => {
      expect(findAvailabilityCheckbox().props('disabled')).toBe(true);
    });
  });

  describe('when duoSastFpDetectionCascadingSettings.lockedByAncestor is true', () => {
    beforeEach(() => {
      wrapper = createWrapper(
        {},
        {
          duoSastFpDetectionCascadingSettings: {
            lockedByAncestor: true,
            lockedByApplicationSetting: false,
          },
        },
      );
    });

    it('shows cascading lock icon', () => {
      expect(findCascadingLock().exists()).toBe(true);
    });

    it('disables the checkbox', () => {
      expect(findAvailabilityCheckbox().props('disabled')).toBe(true);
    });
  });

  describe('when isGroupSettings is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({}, { isGroupSettings: true });
    });

    it('renders the group description', () => {
      expect(wrapper.text()).toContain(
        'Turn on False Positive Detection for Vulnerabilities on default branch in this group and its subgroups and projects',
      );
    });
  });

  describe('when isGroupSettings is false', () => {
    beforeEach(() => {
      wrapper = createWrapper({}, { isGroupSettings: false });
    });

    it('renders the instance description', () => {
      expect(wrapper.text()).toContain(
        'Turn on False Positive Detection for Vulnerabilities on default branch for the instance',
      );
    });
  });

  describe('checkbox interaction', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('emits change event when checkbox is clicked', async () => {
      await findAvailabilityCheckbox().vm.$emit('change');

      expect(wrapper.emitted('change')).toHaveLength(1);
    });

    it('updates internal state when checkbox value changes', async () => {
      expect(findAvailabilityCheckbox().props('checked')).toBe(false);

      await findAvailabilityCheckbox().vm.$emit('input', true);

      expect(findAvailabilityCheckbox().props('checked')).toBe(true);
    });
  });

  describe('cascading settings integration', () => {
    it('passes correct props to CascadingLockIcon when locked by ancestor', () => {
      wrapper = createWrapper(
        {},
        {
          duoSastFpDetectionCascadingSettings: {
            lockedByAncestor: true,
            lockedByApplicationSetting: false,
          },
        },
      );

      const cascadingLock = findCascadingLock();
      expect(cascadingLock.props()).toMatchObject({
        isLockedByGroupAncestor: true,
        isLockedByApplicationSettings: false,
      });
    });

    it('passes correct props to CascadingLockIcon when locked by application settings', () => {
      wrapper = createWrapper(
        {},
        {
          duoSastFpDetectionCascadingSettings: {
            lockedByAncestor: false,
            lockedByApplicationSetting: true,
          },
        },
      );

      const cascadingLock = findCascadingLock();
      expect(cascadingLock.props()).toMatchObject({
        isLockedByGroupAncestor: false,
        isLockedByApplicationSettings: true,
      });
    });
  });
});
