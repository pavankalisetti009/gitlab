import { nextTick } from 'vue';
import { GlTable, GlFormCheckbox, GlFormGroup, GlLink, GlButton } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiNamespaceAccessRules from 'ee/ai/settings/components/ai_namespace_access_rules.vue';
import GroupSelector from 'ee/ai/settings/components/group_selector.vue';

describe('AiNamespaceAccessRules', () => {
  let wrapper;

  const mockNamespaceAccessRules = [
    {
      throughNamespace: {
        id: 1,
        name: 'Group A',
        fullPath: 'group-a',
      },
      features: ['duo_agent_platform'],
    },
    {
      throughNamespace: {
        id: 2,
        name: 'Group B',
        fullPath: 'group-b',
      },
      features: ['duo_classic'],
    },
  ];

  const createComponent = ({ props = {}, mountFn = shallowMountExtended, stubs = {} } = {}) => {
    wrapper = mountFn(AiNamespaceAccessRules, {
      propsData: {
        initialNamespaceAccessRules: mockNamespaceAccessRules,
        ...props,
      },
      stubs: {
        GroupSelector: true,
        ...stubs,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findHelpLink = () => wrapper.findAllComponents(GlLink).at(0);
  const findTable = () => wrapper.findComponent(GlTable);
  const findNamespaceLinks = () =>
    wrapper
      .find('table')
      .findAllComponents(GlLink)
      .filter((link) => link.attributes('target') === '_blank');
  const findCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findGroupSelector = () => wrapper.findComponent(GroupSelector);
  const findRemoveButtons = () =>
    wrapper.findAllComponents(GlButton).filter((btn) => btn.text() === 'Remove');

  describe('when access rules array is empty', () => {
    beforeEach(() => {
      createComponent({ props: { initialNamespaceAccessRules: [] } });
    });

    it('renders the table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('displays the empty state message', () => {
      expect(wrapper.text()).toContain('No access rules configured');
    });
  });

  describe('when initialNamespaceAccessRules is provided', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('renders the form group with correct label', () => {
      expect(findFormGroup().text()).toContain('Member access');
    });

    it('renders the help text', () => {
      expect(wrapper.text()).toContain(
        'Only members of these groups will have access to selected AI features.',
      );
    });

    it('renders the learn more link with correct href', () => {
      expect(findHelpLink().exists()).toBe(true);
      expect(findHelpLink().attributes('href')).toBe(
        '/help/administration/gitlab_duo/configure/access_control.md',
      );
      expect(findHelpLink().text()).toBe('Learn more');
    });

    it('renders the table with access rules data', () => {
      expect(findTable().props('items')).toEqual(mockNamespaceAccessRules);
    });

    it('renders the table with correct fields', () => {
      expect(findTable().props('fields')).toEqual([
        {
          key: 'namespaceName',
          label: 'Group',
          thStyle: { width: '40%' },
          tdClass: 'gl-max-w-0',
        },
        {
          key: 'features',
          label: 'Membership grants access to',
          thStyle: { width: '40%' },
          tdClass: 'gl-max-w-0',
        },
        {
          key: 'actions',
          label: null,
          thStyle: { width: '20%' },
          tdClass: 'gl-max-w-0',
        },
      ]);
    });

    describe('namespace links', () => {
      it('renders namespace links with correct href and text', () => {
        const links = findNamespaceLinks();

        expect(links.at(0).attributes('href')).toBe('/group-a');
        expect(links.at(0).text()).toBe('Group A');

        expect(links.at(1).attributes('href')).toBe('/group-b');
        expect(links.at(1).text()).toBe('Group B');
      });
    });

    describe('enabled features checkboxes', () => {
      it('renders checkbox for all features for each rule', () => {
        const checkboxes = findCheckboxes();
        expect(checkboxes).toHaveLength(4);
      });

      it('renders checkbox labels for all available features', () => {
        const checkboxes = findCheckboxes();

        expect(checkboxes.at(0).text()).toBe('GitLab Duo Classic');
        expect(checkboxes.at(1).text()).toBe('GitLab Duo Agent Platform');
      });

      it('checks the correct checkboxes based on configuration', () => {
        const checkboxes = findCheckboxes();

        expect(checkboxes.at(0).props('checked')).toBe(false);
        expect(checkboxes.at(1).props('checked')).toBe(true);

        expect(checkboxes.at(2).props('checked')).toBe(true);
        expect(checkboxes.at(3).props('checked')).toBe(false);
      });
    });

    describe('remove namespace access rule', () => {
      it('removes the namespace access rule with matching id', async () => {
        expect(findTable().props('items')).toHaveLength(2);

        await findRemoveButtons().at(0).trigger('click');
        await nextTick();

        const items = findTable().props('items');

        expect(items).toHaveLength(1);
        expect(items).toEqual([mockNamespaceAccessRules[1]]);
      });

      it('emits change event with updated namespace access rules', async () => {
        await findRemoveButtons().at(1).trigger('click');

        expect(wrapper.emitted('change')).toHaveLength(1);
        expect(wrapper.emitted('change')[0][0]).toEqual([mockNamespaceAccessRules[0]]);
      });
    });

    describe('when feature is toggled', () => {
      it('enables feature for specific namespace access rule', async () => {
        await findCheckboxes().at(0).vm.$emit('change', true);
        await nextTick();

        expect(wrapper.emitted('change')).toHaveLength(1);
        expect(wrapper.emitted('change')[0][0]).toEqual([
          {
            throughNamespace: { id: 1, name: 'Group A', fullPath: 'group-a' },
            features: ['duo_agent_platform', 'duo_classic'], // Now has both features
          },
          {
            throughNamespace: { id: 2, name: 'Group B', fullPath: 'group-b' },
            features: ['duo_classic'],
          },
        ]);
      });

      it('disables feature for specific namespace access rule', async () => {
        await findCheckboxes().at(1).vm.$emit('change', false);
        await nextTick();

        expect(wrapper.emitted('change')).toHaveLength(1);
        expect(wrapper.emitted('change')[0][0]).toEqual([
          {
            throughNamespace: { id: 1, name: 'Group A', fullPath: 'group-a' },
            features: [],
          },
          {
            throughNamespace: { id: 2, name: 'Group B', fullPath: 'group-b' },
            features: ['duo_classic'],
          },
        ]);
      });

      it('de-duplicates features for namespace access rules', async () => {
        await findCheckboxes().at(1).vm.$emit('change', true);
        await nextTick();

        expect(wrapper.emitted('change')).toHaveLength(1);
        expect(wrapper.emitted('change')[0][0]).toEqual([
          {
            throughNamespace: { id: 1, name: 'Group A', fullPath: 'group-a' },
            features: ['duo_agent_platform'],
          },
          {
            throughNamespace: { id: 2, name: 'Group B', fullPath: 'group-b' },
            features: ['duo_classic'],
          },
        ]);
      });
    });
  });

  describe('GroupSelector', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('adds new namespace to access rules when namespace is selected', async () => {
      const namespace1 = {
        id: 'gid://gitlab/Group/9',
        name: 'Group C',
        fullPath: 'group-c',
      };

      const namespace2 = {
        id: 'gid://gitlab/Group/10',
        name: 'Group D',
        fullPath: 'group-d',
      };

      findGroupSelector().vm.$emit('group-selected', namespace1);
      await nextTick();
      findGroupSelector().vm.$emit('group-selected', namespace2);
      await nextTick();

      const links = findNamespaceLinks();
      const checkboxes = findCheckboxes();

      expect(links).toHaveLength(4);

      expect(links.at(2).attributes('href')).toBe('/group-c');
      expect(links.at(2).text()).toBe('Group C');

      expect(checkboxes.at(6).props('checked')).toBe(true);
      expect(checkboxes.at(7).props('checked')).toBe(true);

      expect(links.at(3).attributes('href')).toBe('/group-d');
      expect(links.at(3).text()).toBe('Group D');
    });

    it('skips new namespace when namespace is already added', async () => {
      const namespace1 = {
        id: 'gid://gitlab/Group/9',
        name: 'Group C',
        fullPath: 'group-c',
      };

      findGroupSelector().vm.$emit('group-selected', namespace1);
      await nextTick();

      expect(findNamespaceLinks()).toHaveLength(3);

      findGroupSelector().vm.$emit('group-selected', namespace1);
      await nextTick();

      expect(findNamespaceLinks()).toHaveLength(3);
    });

    it('emits namespace access rules when namespace is added', async () => {
      const namespace1 = {
        id: 'gid://gitlab/Group/3',
        name: 'Group C',
        fullPath: 'group-c',
      };

      findGroupSelector().vm.$emit('group-selected', namespace1);
      await nextTick();

      expect(wrapper.emitted('change')[0][0]).toEqual([
        {
          features: ['duo_agent_platform'],
          throughNamespace: {
            fullPath: 'group-a',
            id: 1,
            name: 'Group A',
          },
        },
        {
          features: ['duo_classic'],
          throughNamespace: {
            fullPath: 'group-b',
            id: 2,
            name: 'Group B',
          },
        },
        {
          features: ['duo_classic', 'duo_agent_platform'],
          throughNamespace: {
            fullPath: 'group-c',
            id: 3,
            name: 'Group C',
          },
        },
      ]);
    });
  });
});
