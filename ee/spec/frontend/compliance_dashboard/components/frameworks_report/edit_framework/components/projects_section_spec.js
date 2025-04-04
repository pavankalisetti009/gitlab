import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTable } from '@gitlab/ui';

import ProjectsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/projects_section.vue';
import VisibilityIconButton from '~/vue_shared/components/visibility_icon_button.vue';
import createMockApollo from 'helpers/mock_apollo_helper';

import { mountExtended } from 'helpers/vue_test_utils_helper';

import getNamespaceProjectsWithNamespacesQuery from 'ee/graphql_shared/queries/get_namespace_projects_with_namespaces.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { createFramework, createProject } from '../../../../mock_data';

Vue.use(VueApollo);

describe('Projects section', () => {
  let wrapper;
  let apolloProvider;

  const framework = createFramework({ id: 1, projects: 3 });
  const projects = framework.projects.nodes;

  const createMockApolloProvider = (resolverMock) => {
    const requestHandlers = [[getNamespaceProjectsWithNamespacesQuery, resolverMock]];
    return createMockApollo(requestHandlers);
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const projectLinks = () => wrapper.findAllByTestId('project-link');
  const subgroupLinks = () => wrapper.findAllByTestId('subgroup-link');
  const findCheckbox = (idx) => findTableRow(idx).find('input[type="checkbox"]');
  const findSelectAllCheckbox = () => wrapper.find('thead input[type="checkbox"]');

  const mockProjects = Array.from({ length: 5 }, (_, id) =>
    createProject({ id, groupPath: 'foo' }),
  );

  const createComponent = ({
    resolverMock = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: 'gid://gitlab/Group/1',
          projects: {
            nodes: mockProjects,
          },
        },
      },
    }),
  } = {}) => {
    apolloProvider = createMockApolloProvider(resolverMock);

    wrapper = mountExtended(ProjectsSection, {
      apolloProvider,
      propsData: {
        complianceFramework: framework,
        namespacePath: 'gitlab-org',
      },
    });
  };

  describe('when loaded', () => {
    beforeEach(async () => {
      createComponent();
      await nextTick();
    });

    it('renders title', () => {
      const title = wrapper.findByText('Projects');
      expect(title.exists()).toBe(true);
    });

    it('correctly displays description', () => {
      const description = wrapper.findByText(
        "All selected projects will be covered by the framework's selected requirements and the policies.",
      );
      expect(description).toBeDefined();
    });

    it('correctly calculates projects', () => {
      const { items } = findTable().vm.$attrs;
      expect(items).toHaveLength(5);
    });

    it.each(Object.keys(projects))('has the correct data for row %s', (idx) => {
      const frameworkProjects = findTableRowData(idx).wrappers.map((d) => d.text());

      expect(frameworkProjects[1]).toMatch(projects[idx].name);
      expect(frameworkProjects[2]).toMatch(projects[idx].namespace.fullName);
      expect(frameworkProjects[3]).toMatch(projects[idx].description);
    });

    it.each(Object.keys(projects))('has the correct visibility icon for row %s', (idx) => {
      const frameworkProjects = findTableRowData(idx).wrappers.map((d) => d);

      const visibilityIcon = frameworkProjects[1].findComponent(VisibilityIconButton);
      expect(visibilityIcon.exists()).toBe(true);
      expect(visibilityIcon.props('visibilityLevel')).toMatch(projects[idx].visibility);
    });

    it.each(Object.keys(projects))('renders correct url for the projects %s', (idx) => {
      expect(projectLinks().at(idx).attributes('href')).toBe(projects[idx].webUrl);
    });

    it.each(Object.keys(projects))('renders correct url for the projects subgroup %s', (idx) => {
      expect(subgroupLinks().at(idx).attributes('href')).toBe(projects[idx].namespace.webUrl);
    });

    describe('project selection', () => {
      it('selects all projects when select all checkbox is clicked', async () => {
        const selectAllCheckbox = findSelectAllCheckbox();
        await selectAllCheckbox.setChecked(true);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        const lastEvent = emittedEvents[emittedEvents.length - 1][0];

        expect(lastEvent.addProjects).toHaveLength(wrapper.findAll('tbody > tr').length);
        expect(lastEvent.removeProjects).toHaveLength(0);
      });

      it('deselects all projects when select all checkbox is unchecked', async () => {
        const selectAllCheckbox = findSelectAllCheckbox();
        await selectAllCheckbox.setChecked(true);
        await nextTick();
        await selectAllCheckbox.setChecked(false);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        const lastEvent = emittedEvents[emittedEvents.length - 1][0];
        expect(lastEvent.addProjects).toHaveLength(0);
        expect(lastEvent.removeProjects).toHaveLength(wrapper.findAll('tbody > tr').length);
      });

      it('selects individual project when checkbox is clicked', async () => {
        const checkbox = findCheckbox(4);
        await checkbox.setChecked(true);
        await nextTick();

        expect(checkbox.element.checked).toBe(true);

        const emittedEvents = wrapper.emitted('update:projects');
        expect(emittedEvents[0][0].addProjects).toContain(getIdFromGraphQLId(mockProjects[4].id));
      });

      it('emits update:projects event with correct data when projects are selected', async () => {
        await findCheckbox(4).setChecked(true);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        expect(emittedEvents).toHaveLength(1);
        const [eventData] = emittedEvents[0];
        expect(eventData).toEqual({
          addProjects: [getIdFromGraphQLId(mockProjects[4].id)],
          removeProjects: [],
        });
      });

      it('emits update:projects event when multiple projects are selected', async () => {
        await findCheckbox(3).setChecked(true);
        await nextTick();
        await findCheckbox(4).setChecked(true);
        await nextTick();
        await findCheckbox(4).setChecked(false);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        expect(emittedEvents).toHaveLength(3);
        const [lastEventData] = emittedEvents[2];
        expect(lastEventData).toEqual({
          addProjects: [getIdFromGraphQLId(mockProjects[3].id)],
          removeProjects: [getIdFromGraphQLId(mockProjects[4].id)],
        });
      });

      it('emits update:projects event when projects are deselected', async () => {
        await findCheckbox(4).setChecked(true);
        await nextTick();
        await findCheckbox(4).setChecked(false);
        await nextTick();

        const emittedEvents = wrapper.emitted('update:projects');
        expect(emittedEvents).toHaveLength(2);
        const [lastEventData] = emittedEvents[1];

        expect(lastEventData).toEqual({
          addProjects: [],
          removeProjects: [getIdFromGraphQLId(mockProjects[4].id)],
        });
      });

      it('emits update:projects event when all projects are selected and deselected', async () => {
        await findSelectAllCheckbox().setChecked(true);
        await nextTick();

        const selectEmittedEvents = wrapper.emitted('update:projects');
        const lastSelectEvent = selectEmittedEvents[selectEmittedEvents.length - 1][0];

        const totalProjects = wrapper.findAll('tbody > tr').length;
        expect(lastSelectEvent.addProjects).toHaveLength(totalProjects);
        expect(lastSelectEvent.removeProjects).toHaveLength(0);

        await findSelectAllCheckbox().setChecked(false);
        await nextTick();

        const allEmittedEvents = wrapper.emitted('update:projects');
        const lastDeselectEvent = allEmittedEvents[allEmittedEvents.length - 1][0];
        expect(lastDeselectEvent.removeProjects).toHaveLength(totalProjects);
        expect(lastDeselectEvent.addProjects).toHaveLength(0);
      });
    });

    describe('computed properties', () => {
      it('correctly displays associated projects', () => {
        const projectRows = wrapper.findAll('tbody > tr');
        expect(projectRows).toHaveLength(5);

        projects.forEach((project, index) => {
          const projectName = findTableRowData(index).at(1).text();
          expect(projectName).toContain(project.name);
        });
      });

      it('correctly displays non-associated projects', () => {
        const projectRows = wrapper.findAll('tbody > tr');

        mockProjects.forEach((project) => {
          const projectRow = projectRows.wrappers.find((row) => row.text().includes(project.name));
          expect(projectRow).toBeDefined();
        });
      });
    });
  });

  describe('error handling', () => {
    it('handles Apollo query errors', async () => {
      const error = new Error('GraphQL Error');
      createComponent({
        resolverMock: jest.fn().mockRejectedValue(error),
      });

      await waitForPromises();

      const errorMessage = wrapper.findByText('Error loading projects.');
      expect(errorMessage.exists()).toBe(true);

      const projectRows = wrapper.findAll('tbody > tr');
      expect(projectRows).toHaveLength(0);
    });
  });
});
