import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormGroup, GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import DuoFlowSettings from 'ee/ai/settings/components/duo_flow_settings.vue';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';

describe('DuoFlowSettings', () => {
  let wrapper;
  const defaultProvide = {
    isSaaS: true,
    isGroupSettings: false,
    glFeatures: {
      duoFoundationalFlows: true,
    },
    duoRemoteFlowsCascadingSettings: {
      lockedByAncestor: false,
      lockedByApplicationSettings: false,
    },
    duoFoundationalFlowsCascadingSettings: {
      lockedByAncestor: false,
      lockedByApplicationSettings: false,
    },
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findRemoteFlowsCheckbox = () => wrapper.findAllComponents(GlFormCheckbox).at(0);
  const findFoundationalFlowsCheckbox = () => wrapper.findAllComponents(GlFormCheckbox).at(1);
  const findAllLockIcons = () => wrapper.findAllComponents(GlIcon);
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findAllLockButtons = () =>
    wrapper.findAll('[data-testid="duo-flow-feature-checkbox-locked"]');
  const findAllCascadingLocks = () => wrapper.findAllComponents(CascadingLockIcon);
  const findAllCheckBoxes = () => wrapper.findAllComponents(GlFormCheckbox);

  const createWrapper = (props = {}, provide = {}) => {
    return shallowMount(DuoFlowSettings, {
      propsData: {
        disabledCheckbox: false,
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
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

    it('renders both checkboxes', () => {
      expect(wrapper.findAllComponents(GlFormCheckbox)).toHaveLength(2);
    });

    it('renders the remote flows checkbox with correct label', () => {
      expect(findRemoteFlowsCheckbox().exists()).toBe(true);
      expect(wrapper.findAll('#duo-flow-checkbox-label').at(0).text()).toBe('Allow flow execution');
    });

    it('renders the foundational flows checkbox with correct label', () => {
      expect(findFoundationalFlowsCheckbox().exists()).toBe(true);
      expect(wrapper.findAll('#duo-flow-checkbox-label').at(1).text()).toBe(
        'Allow foundational flows',
      );
    });

    it('sets initial remote flows checkbox state based on duoRemoteFlowsAvailability prop', () => {
      expect(findRemoteFlowsCheckbox().props('checked')).toBe(false);
    });

    it('sets initial foundational flows checkbox state based on duoFoundationalFlowsAvailability prop', () => {
      expect(findFoundationalFlowsCheckbox().props('checked')).toBe(false);
    });

    it('renders help link with correct href', () => {
      expect(findHelpLink().exists()).toBe(true);
      expect(findHelpLink().attributes('href')).toBe(
        '/help/user/duo_agent_platform/flows/_index.md',
      );
      expect(findHelpLink().attributes('target')).toBe('_blank');
    });

    it('does not render cascading locks by default', () => {
      expect(findAllCascadingLocks()).toHaveLength(0);
    });

    it('shows lock on foundational flows when remote flows is disabled', () => {
      expect(findFoundationalFlowsCheckbox().props('disabled')).toBe(true);
      expect(findAllLockButtons()).toHaveLength(1);
    });
  });

  describe('when duoRemoteFlowsAvailability is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({ duoRemoteFlowsAvailability: true });
    });

    it('sets remote flows checkbox as checked', () => {
      expect(findRemoteFlowsCheckbox().props('checked')).toBe(true);
    });

    it('enables the foundational flows checkbox', () => {
      expect(findFoundationalFlowsCheckbox().attributes('disabled')).toBe(undefined);
    });

    it('does not show lock on foundational flows', () => {
      expect(findAllLockButtons()).toHaveLength(0);
    });
  });

  describe('when duoFoundationalFlowsAvailability is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        duoRemoteFlowsAvailability: true,
        duoFoundationalFlowsAvailability: true,
      });
    });

    it('sets foundational flows checkbox as checked', () => {
      expect(findFoundationalFlowsCheckbox().props('checked')).toBe(true);
    });
  });

  describe('when disabledCheckbox is false', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        disabledCheckbox: false,
        duoRemoteFlowsAvailability: true,
      });
    });

    it('enables the remote flows checkbox', () => {
      expect(findRemoteFlowsCheckbox().attributes('disabled')).toBe(undefined);
    });

    it('enables the foundational flows checkbox when remote flows is enabled', () => {
      expect(findFoundationalFlowsCheckbox().attributes('disabled')).toBe(undefined);
    });

    it('does not show any lock icons', () => {
      expect(findAllLockButtons()).toHaveLength(0);
    });
  });

  describe('when disabledCheckbox is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({ disabledCheckbox: true });
    });

    it('disables both checkboxes', () => {
      expect(findRemoteFlowsCheckbox().props('disabled')).toBe(true);
      expect(findFoundationalFlowsCheckbox().props('disabled')).toBe(true);
    });

    it('shows lock icons on both checkboxes', () => {
      expect(findAllLockButtons()).toHaveLength(2);
      expect(findAllLockIcons()).toHaveLength(2);
    });
  });

  describe('when remote flows is disabled', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
      });
    });

    it('disables the foundational flows checkbox', () => {
      expect(findFoundationalFlowsCheckbox().props('disabled')).toBe(true);
    });

    it('shows lock icon on foundational flows only', () => {
      expect(findAllLockButtons()).toHaveLength(1);
    });
  });

  describe('cascading locks for remote flows', () => {
    describe('when locked by application setting', () => {
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

      it('shows cascading lock', () => {
        expect(findAllCascadingLocks()).toHaveLength(1);
        expect(findAllCascadingLocks().at(0).props('isLockedByApplicationSettings')).toBe(true);
      });
    });

    describe('when locked by ancestor', () => {
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

      it('shows cascading lock', () => {
        expect(findAllCascadingLocks()).toHaveLength(1);
        expect(findAllCascadingLocks().at(0).props('isLockedByGroupAncestor')).toBe(true);
      });
    });
  });

  describe('cascading locks for foundational flows', () => {
    describe('when locked by application setting', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {},
          {
            duoFoundationalFlowsCascadingSettings: {
              lockedByAncestor: false,
              lockedByApplicationSetting: true,
            },
          },
        );
      });

      it('shows cascading lock', () => {
        expect(findAllCascadingLocks()).toHaveLength(1);
        expect(findAllCascadingLocks().at(0).props('isLockedByApplicationSettings')).toBe(true);
      });
    });

    describe('when locked by ancestor', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {},
          {
            duoFoundationalFlowsCascadingSettings: {
              lockedByAncestor: true,
              lockedByApplicationSetting: false,
            },
          },
        );
      });

      it('shows cascading lock', () => {
        expect(findAllCascadingLocks()).toHaveLength(1);
        expect(findAllCascadingLocks().at(0).props('isLockedByGroupAncestor')).toBe(true);
      });
    });

    describe('when both checkboxes are locked', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {},
          {
            duoRemoteFlowsCascadingSettings: {
              lockedByAncestor: true,
              lockedByApplicationSetting: false,
            },
            duoFoundationalFlowsCascadingSettings: {
              lockedByAncestor: false,
              lockedByApplicationSetting: true,
            },
          },
        );
      });

      it('shows both cascading locks', () => {
        expect(findAllCascadingLocks()).toHaveLength(2);
      });
    });
  });

  describe('help text variations', () => {
    describe('when isGroupSettings is true', () => {
      beforeEach(() => {
        wrapper = createWrapper({}, { isGroupSettings: true });
      });

      it('renders the group-specific help text for remote flows', () => {
        expect(wrapper.text()).toContain('this group and its subgroups and projects');
      });

      it('renders the group-specific help text for foundational flows', () => {
        expect(wrapper.text()).toContain(
          'Allow GitLab Duo agents to execute foundational flows in this group and its subgroups and projects',
        );
      });
    });

    describe('when isGroupSettings is false', () => {
      beforeEach(() => {
        wrapper = createWrapper({}, { isGroupSettings: false });
      });

      it('renders the instance-specific help text for remote flows', () => {
        expect(wrapper.text()).toContain('for the instance');
      });

      it('renders the instance-specific help text for foundational flows', () => {
        expect(wrapper.text()).toContain(
          'Allow GitLab Duo agents to execute foundational flows for the instance',
        );
      });
    });
  });

  describe('checkbox interactions', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('emits change event when remote flows checkbox is clicked', async () => {
      await findRemoteFlowsCheckbox().vm.$emit('change');

      expect(wrapper.emitted('change')).toHaveLength(1);
    });

    it('emits change-foundational-flows event when foundational flows checkbox is clicked', async () => {
      await findFoundationalFlowsCheckbox().vm.$emit('change');

      expect(wrapper.emitted('change-foundational-flows')).toHaveLength(1);
    });
  });

  describe('when duoFoundationalFlows feature flag is disabled', () => {
    beforeEach(() => {
      wrapper = createWrapper(
        { duoRemoteFlowsAvailability: true },
        {
          glFeatures: { duoFoundationalFlows: false },
        },
      );
    });

    it('only renders the remote flows checkbox', () => {
      expect(findAllCheckBoxes()).toHaveLength(1);
    });

    it('does not render the foundational flows checkbox', () => {
      expect(wrapper.find('[data-testid="duo-foundational-flows-checkbox"]').exists()).toBe(false);
    });
  });
});
