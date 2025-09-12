import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormGroup, GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import DuoFlowSettings from 'ee/ai/settings/components/duo_flow_settings.vue';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';

describe('DuoFlowSettings', () => {
  let wrapper;
  const defaultProvide = {
    isSaaS: true,
    isGroupSettings: false,
    duoRemoteFlowsCascadingSettings: {
      lockedByAncestor: false,
      lockedByApplicationSettings: false,
    },
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findAvailabilityCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findLockIcon = () => wrapper.findComponent(GlIcon);
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findLockButton = () => wrapper.find('[data-testid="duo-flow-feature-checkbox-locked"]');
  const findCascadingLock = () => wrapper.findComponent(CascadingLockIcon);

  const createWrapper = (props = {}, provide = {}) => {
    return shallowMount(DuoFlowSettings, {
      propsData: {
        disabledCheckbox: false,
        duoRemoteFlowsAvailability: false,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        GlFormCheckbox,
        GlFormGroup,
        GlIcon,
        GlLink,
        GlSprintf,
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('renders the form group with correct label', () => {
      expect(findFormGroup().exists()).toBe(true);
      expect(findFormGroup().attributes('label')).toBe('Flow execution');
    });

    it('renders the checkbox with correct label', () => {
      expect(findAvailabilityCheckbox().exists()).toBe(true);
      expect(wrapper.find('#duo-flow-checkbox-label').text()).toBe('Allow flow execution');
    });

    it('sets initial checkbox state based on duoRemoteFlowsAvailability prop', () => {
      expect(findAvailabilityCheckbox().props('checked')).toBe(false);
    });

    it('renders help link with correct href', () => {
      expect(findHelpLink().exists()).toBe(true);
      expect(findHelpLink().attributes('href')).toBe(
        '/help/user/duo_agent_platform/flows/_index.md',
      );
      expect(findHelpLink().attributes('target')).toBe('_blank');
    });

    it('does not render the cascading lock', () => {
      expect(findCascadingLock().exists()).toBe(false);
    });
  });

  describe('when duoRemoteFlowsAvailability is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({ duoRemoteFlowsAvailability: true });
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

  describe('when duoRemoteFlowsCascadingSettings.lockedByApplicationSetting is true', () => {
    beforeEach(() => {
      wrapper = createWrapper(
        {},
        {
          duoRemoteFlowsCascadingSettings: {
            lockedByAncestor: false,
            lockedByApplicationSetting: true,
          },
        },
      );
    });

    it('shows cascading lock icon', () => {
      expect(findCascadingLock().exists()).toBe(true);
    });
  });

  describe('when duoRemoteFlowsCascadingSettings.lockedByAncestor is true', () => {
    beforeEach(() => {
      wrapper = createWrapper(
        {},
        {
          duoRemoteFlowsCascadingSettings: {
            lockedByAncestor: true,
            lockedByApplicationSetting: false,
          },
        },
      );
    });

    it('shows cascading lock icon', () => {
      expect(findCascadingLock().exists()).toBe(true);
    });
  });

  describe('when isGroupSettings is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({}, { isGroupSettings: true });
    });

    it('renders the group copy', () => {
      expect(wrapper.text()).toContain('this group and its subgroups and projects');
    });
  });

  describe('when isGroupSettings is false', () => {
    beforeEach(() => {
      wrapper = createWrapper({}, { isGroupSettings: false });
    });
    it('renders the group copy', () => {
      expect(wrapper.text()).toContain('for the instance');
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
  });
});
