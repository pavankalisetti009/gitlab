import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTableLite, GlBreadcrumb, GlButton } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import InventoryDashboard from 'ee/security_inventory/components/inventory_dashboard.vue';
import VulnerabilityIndicator from 'ee/security_inventory/components/vulnerability_indicator.vue';
import GroupToolCoverageIndicator from 'ee/security_inventory/components/group_tool_coverage_indicator.vue';
import ProjectToolCoverageIndicator from 'ee/security_inventory/components/project_tool_coverage_indicator.vue';
import SubgroupsAndProjectsQuery from 'ee/security_inventory/graphql/subgroups_and_projects.query.graphql';
import SubgroupSidebar from 'ee/security_inventory/components/sidebar/subgroup_sidebar.vue';
import EmptyState from 'ee/security_inventory/components/empty_state.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import vulnerabilityCell from 'ee/security_inventory/components/vulnerability_cell.vue';
import ToolCoverageCell from 'ee/security_inventory/components/tool_coverage_cell.vue';
import ActionCell from 'ee/security_inventory/components/action_cell.vue';
import SecurityInventoryTable from 'ee/security_inventory/components/security_inventory_table.vue';
import { subgroupsAndProjects } from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('InventoryDashboard', () => {
  let wrapper;
  let apolloProvider;
  let requestHandler = '';

  const childrenResolver = jest.fn().mockResolvedValue(subgroupsAndProjects);
  const mockChildren = [
    ...subgroupsAndProjects.data.group.descendantGroups.nodes,
    ...subgroupsAndProjects.data.group.projects.nodes,
  ];

  const defaultProvide = {
    groupFullPath: 'group/project',
    newProjectPath: '/new',
  };

  const createComponentFactory =
    (mountFn = shallowMountExtended) =>
    async ({ resolver = childrenResolver } = {}) => {
      requestHandler = resolver;
      apolloProvider = createMockApollo([[SubgroupsAndProjectsQuery, resolver]]);
      wrapper = mountFn(InventoryDashboard, {
        apolloProvider,
        provide: defaultProvide,
        stubs: {
          SubgroupSidebar: stubComponent(SubgroupSidebar),
        },
      });
      await waitForPromises();
    };

  const createComponent = createComponentFactory();
  const createFullComponent = createComponentFactory(mountExtended);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findEmptyState = () => wrapper.findComponent(EmptyState);
  const findTableRows = () => findTable().findAll('tbody tr');
  const findNthTableRow = (n) => findTableRows().at(n);
  const findBreadcrumb = () => wrapper.findComponent(GlBreadcrumb);
  const findSidebar = () => wrapper.findComponent(SubgroupSidebar);
  const findSidebarToggleButton = () => wrapper.findComponent(GlButton);
  const findInventoryTable = () => wrapper.findComponent(SecurityInventoryTable);

  /* eslint-disable no-underscore-dangle */
  const getIndexByType = (children, type) => {
    return children.findIndex((child) => child.__typename === type);
  };
  /* eslint-enable no-underscore-dangle */

  beforeEach(async () => {
    await createComponent();
  });

  it('displays default state correctly', () => {
    expect(wrapper.exists()).toBe(true);

    expect(findEmptyState().exists()).toBe(false);
    expect(findInventoryTable().exists()).toBe(true);
    expect(findInventoryTable().props('isLoading')).toBe(false);
  });

  describe('Loading state', () => {
    beforeEach(async () => {
      const mockHandler = jest.fn().mockImplementation(() => new Promise(() => {}));
      await createComponent({ resolver: mockHandler });
    });

    it('sets loading state correctly', () => {
      expect(findInventoryTable().props('isLoading')).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe('Empty state', () => {
    it('displays empty state when there are no children', async () => {
      const emptyResolver = jest.fn().mockResolvedValue({
        data: { group: { descendantGroups: { nodes: [] }, projects: { nodes: [] } } },
      });
      await createComponent({ resolver: emptyResolver });
      await waitForPromises();

      expect(findEmptyState().exists()).toBe(true);
    });
  });

  describe('Table rendering', () => {
    const groupIndex = getIndexByType(mockChildren, 'Group');
    const projectIndex = getIndexByType(mockChildren, 'Project');

    beforeEach(async () => {
      await createFullComponent();
    });

    it('renders the GlTableLite component with correct fields', () => {
      expect(findTable().exists()).toBe(true);
      expect(findTable().props('fields')).toHaveLength(4);
      expect(
        findTable()
          .props('fields')
          .map((field) => field.key),
      ).toEqual(['name', 'vulnerabilities', 'toolCoverage', 'actions']);
    });

    it('renders correct values in table cells for projects and subgroups', () => {
      expect(findTableRows()).toHaveLength(mockChildren.length);

      const nameCell = findNthTableRow(groupIndex).findComponent(NameCell);
      expect(nameCell.exists()).toBe(true);
      expect(nameCell.text()).toContain(mockChildren[0].name);

      const vulnerabilitycell = findNthTableRow(groupIndex).findComponent(vulnerabilityCell);
      expect(vulnerabilitycell.exists()).toBe(true);
      expect(vulnerabilitycell.text()).toContain('80');

      const toolCoverageCell = findNthTableRow(groupIndex).findComponent(ToolCoverageCell);
      expect(toolCoverageCell.exists()).toBe(true);

      const actionCell = findNthTableRow(projectIndex).findComponent(ActionCell);
      expect(actionCell.exists()).toBe(true);
    });

    it('renders correct elements for projects and subgroups', () => {
      const subgroupLink = findNthTableRow(groupIndex).findComponent({ name: 'gl-link' });
      expect(subgroupLink.exists()).toBe(true);
      expect(subgroupLink.attributes('href')).toBe(`#${mockChildren[groupIndex].fullPath}`);

      const projectDiv = findNthTableRow(projectIndex).find('div');
      expect(projectDiv.exists()).toBe(true);
      expect(projectDiv.text()).toContain(mockChildren[projectIndex].name);
    });

    it('renders the vulnerability indicator for projects and subgroups', () => {
      expect(
        findNthTableRow(projectIndex).findComponent(VulnerabilityIndicator).props('counts'),
      ).toStrictEqual({
        critical: 10,
        high: 5,
        low: 4,
        info: 0,
        medium: 48,
        unknown: 7,
      });
      expect(
        findNthTableRow(groupIndex).findComponent(VulnerabilityIndicator).props('counts'),
      ).toStrictEqual({
        critical: 10,
        high: 10,
        low: 10,
        info: 10,
        medium: 20,
        unknown: 20,
      });
    });

    it('renders tool coverage indicators for projects and subgroups', async () => {
      await createFullComponent();

      expect(
        findNthTableRow(projectIndex)
          .findComponent(ProjectToolCoverageIndicator)
          .props('securityScanners'),
      ).toMatchObject({ enabled: ['SAST', 'SAST_ADVANCED'], pipelineRun: ['SAST'] });
      expect(findNthTableRow(groupIndex).findComponent(GroupToolCoverageIndicator).exists()).toBe(
        true,
      );
    });
  });

  describe('Subgroup sidebar', () => {
    it('can be toggled with the sidebar button', async () => {
      await createComponent();

      expect(findSidebar().exists()).toBe(true);

      findSidebarToggleButton().vm.$emit('click');
      await nextTick();

      expect(findSidebar().exists()).toBe(false);
    });

    it('persists visible state through page reloads', async () => {
      createFullComponent();

      findSidebarToggleButton().vm.$emit('click');
      await nextTick();

      expect(findSidebar().exists()).toBe(false);

      wrapper.destroy();
      createFullComponent();
      await nextTick();

      expect(findSidebar().exists()).toBe(false);
    });
  });

  describe('Error handling', () => {
    it('captures exception in Sentry when an unexpected error occurs', async () => {
      jest.spyOn(Sentry, 'captureException');
      const mockErrorResolver = jest.fn().mockRejectedValue(new Error('Unexpected error'));

      await createComponent({ resolver: mockErrorResolver });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'An error occurred while fetching subgroups and projects. Please try again.',
        }),
      );

      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Unexpected error'));
    });
  });

  describe('opening subgroup details', () => {
    it('refetches data when URL hash changes', async () => {
      const newFullPath = 'new-group';
      window.location.hash = `#${newFullPath}`;

      await createComponent();
      expect(requestHandler).toHaveBeenCalledWith({
        fullPath: newFullPath,
      });
    });

    it('fallback to groupFullPath when hash is removed', async () => {
      window.location.hash = '';

      await createComponent();
      expect(requestHandler).toHaveBeenCalledWith({
        fullPath: defaultProvide.groupFullPath,
      });
    });
  });

  describe('Breadcrumb', () => {
    it('renders breadcrumb component with correct items', () => {
      expect(findBreadcrumb().exists()).toBe(true);
      expect(findBreadcrumb().props('items')).toEqual([
        {
          text: 'group',
          to: {
            hash: '#group',
          },
        },
        {
          text: 'project',
          to: {
            hash: '#group/project',
          },
        },
      ]);
    });

    it('updates breadcrumb when activeFullPath changes', async () => {
      window.location.hash = 'group/project/subgroup';

      await createComponent();

      expect(findBreadcrumb().props('items')).toEqual([
        {
          text: 'group',
          to: {
            hash: '#group',
          },
        },
        {
          text: 'project',
          to: {
            hash: '#group/project',
          },
        },
        {
          text: 'subgroup',
          to: {
            hash: '#group/project/subgroup',
          },
        },
      ]);
    });

    it('has auto-resize enabled for breadcrumb', () => {
      expect(findBreadcrumb().props('autoResize')).toBe(true);
    });
  });
});
