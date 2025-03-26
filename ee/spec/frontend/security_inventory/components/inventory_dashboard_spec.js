import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlTableLite, GlSkeletonLoader, GlEmptyState, GlBreadcrumb, GlPopover } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import InventoryDashboard from 'ee/security_inventory/components/inventory_dashboard.vue';
import VulnerabilityIndicator from 'ee/security_inventory/components/vulnerability_indicator.vue';
import SubgroupsAndProjectsQuery from 'ee/security_inventory/graphql/subgroups_and_projects.query.graphql';
import projectVulnerabilityCounts from 'ee/security_inventory/components/project_vulnerability_counts.vue';
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
      });
      await waitForPromises();
    };

  const createComponent = createComponentFactory();
  const createFullComponent = createComponentFactory(mountExtended);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findTableRows = () => findTable().findAll('tbody tr');
  const findNthTableRow = (n) => findTableRows().at(n);
  const findBreadcrumb = () => wrapper.findComponent(GlBreadcrumb);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findProjectVulnerabilityCounts = () => wrapper.findComponent(projectVulnerabilityCounts);
  const findVulnerabilityDiv = () => findNthTableRow(0).findAll('td').at(1).find('div');

  /* eslint-disable no-underscore-dangle */
  const getIndexByType = (children, type) => {
    return children.findIndex((child) => child.__typename === type);
  };
  /* eslint-enable no-underscore-dangle */

  beforeEach(async () => {
    await createComponent();
  });

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  describe('Loading state', () => {
    beforeEach(async () => {
      const mockHandler = jest.fn().mockImplementation(() => new Promise(() => {}));
      await createComponent({ resolver: mockHandler });
    });

    it('shows a skeleton loader when loading', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('Empty state', () => {
    it('renders the empty state when there are no children', async () => {
      const emptyResolver = jest.fn().mockResolvedValue({
        data: { group: { descendantGroups: { nodes: [] }, projects: { nodes: [] } } },
      });
      await createComponent({ resolver: emptyResolver });
      await waitForPromises();

      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().props('title')).toBe('No projects found');
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
      expect(findNthTableRow(0).text()).toContain(mockChildren[0].name);
      expect(findNthTableRow(0).findAll('td').at(2).text()).toBe('N/A');

      expect(findVulnerabilityDiv().text()).toBe('80');
      expect(findVulnerabilityDiv().attributes('id')).toBe('vulnerabilities-count-0');
      expect(findVulnerabilityDiv().classes()).toContain('gl-cursor-pointer');
    });

    it('render current values of vulnerabilities popover', () => {
      expect(findPopover().exists()).toBe(true);
      expect(findProjectVulnerabilityCounts().exists()).toBe(true);
      expect(findPopover().props('target')).toBe(findVulnerabilityDiv().attributes('id'));

      expect(findPopover().text()).toContain(
        'Critical: 10 High: 10 Low: 10 Info: 10 Medium: 20 Unknown: 20',
      );
      expect(findPopover().text()).toContain('View vulnerability report');
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
