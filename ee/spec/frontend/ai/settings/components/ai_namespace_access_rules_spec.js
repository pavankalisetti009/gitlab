import { GlTable, GlFormCheckbox, GlFormGroup, GlLink } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiNamespaceAccessRules from 'ee/ai/settings/components/ai_namespace_access_rules.vue';

describe('AiNamespaceAccessRules', () => {
  let wrapper;

  const mockAccessRules = [
    {
      namespaceName: 'Group A',
      namespacePath: 'group-a',
      enabledFeatures: ['duo_classic', 'duo_agents'],
    },
    {
      namespaceName: 'Group B',
      namespacePath: 'group-b',
      enabledFeatures: ['duo_flows'],
    },
  ];

  const createComponent = ({ props = {}, mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(AiNamespaceAccessRules, {
      propsData: {
        initialNamespaceAccessRules: mockAccessRules,
        ...props,
      },
      stubs: {
        GlTable,
        GlFormGroup,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findHelpLink = () => wrapper.findAllComponents(GlLink).at(0);
  const findTable = () => wrapper.findComponent(GlTable);
  const findNamespaceLinks = () =>
    wrapper.findAllComponents(GlLink).filter((link) => link.attributes('target') === '_blank');
  const findCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);

  describe('when initialNamespaceAccessRules is null', () => {
    beforeEach(() => {
      createComponent({ props: { initialNamespaceAccessRules: null } });
    });

    it('does not render the component', () => {
      expect(findFormGroup().exists()).toBe(false);
      expect(findTable().exists()).toBe(false);
    });
  });

  describe('when access rules array is empty', () => {
    beforeEach(() => {
      createComponent({ props: { initialNamespaceAccessRules: [] }, mountFn: mountExtended });
    });

    it('renders the table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('displays the empty state message', () => {
      expect(wrapper.text()).toContain('No access rules configured.');
    });
  });

  describe('when initialNamespaceAccessRules is provided', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('renders the form group with correct label', () => {
      expect(findFormGroup().text()).toContain('Member Access');
    });

    it('renders the help text', () => {
      expect(wrapper.text()).toContain(
        'Only members of these groups will have access to selected AI features.',
      );
    });

    it('renders the learn more link with correct href', () => {
      expect(findHelpLink().exists()).toBe(true);
      expect(findHelpLink().attributes('href')).toBe('/help/user/ai_features');
      expect(findHelpLink().text()).toBe('Learn more');
    });

    it('renders the table with access rules data', () => {
      expect(findTable().props('items')).toEqual(mockAccessRules);
    });

    it('renders the table with correct fields', () => {
      expect(findTable().props('fields')).toEqual([
        { key: 'namespaceName', label: 'Group' },
        { key: 'enabledFeatures', label: 'Membership grants access to' },
        { key: 'actions', label: null },
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
      it('renders checkboxes for each entity per rule', () => {
        const checkboxes = findCheckboxes();
        expect(checkboxes).toHaveLength(6);
      });

      it('renders checkbox labels for all available entities', () => {
        const checkboxes = findCheckboxes();
        expect(checkboxes.at(0).text()).toBe('GitLab Duo Classic');
        expect(checkboxes.at(1).text()).toBe('GitLab Duo Agents');
        expect(checkboxes.at(2).text()).toBe('GitLab Duo Flows and External Agents');
      });

      it('checks the correct checkboxes based on enabledFeatures', () => {
        const checkboxes = findCheckboxes();

        expect(checkboxes.at(0).props('checked')).toBe(true);
        expect(checkboxes.at(1).props('checked')).toBe(true);
        expect(checkboxes.at(2).props('checked')).toBe(false);

        expect(checkboxes.at(3).props('checked')).toBe(false);
        expect(checkboxes.at(4).props('checked')).toBe(false);
        expect(checkboxes.at(5).props('checked')).toBe(true);
      });
    });
  });
});
