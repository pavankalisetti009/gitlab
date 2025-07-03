import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import { getSystemColorScheme } from '~/lib/utils/css_utils';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ComplianceDashboard from 'ee/compliance_dashboard/components/dashboard/compliance_dashboard.vue';
import FrameworkCoverage from 'ee/compliance_dashboard/components/dashboard/framework_coverage.vue';
import FailedRequirements from 'ee/compliance_dashboard/components/dashboard/failed_requirements.vue';
import FailedControls from 'ee/compliance_dashboard/components/dashboard/failed_controls.vue';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import frameworkCoverageQuery from 'ee/compliance_dashboard/components/dashboard/graphql/framework_coverage.query.graphql';
import failedRequirementsQuery from 'ee/compliance_dashboard/components/dashboard/graphql/failed_requirements.query.graphql';
import failedControlsQuery from 'ee/compliance_dashboard/components/dashboard/graphql/failed_controls.query.graphql';
import { GL_LIGHT } from '~/constants';

Vue.use(VueApollo);

jest.mock('~/alert');
jest.mock('~/lib/utils/css_utils');

getSystemColorScheme.mockReturnValue(GL_LIGHT);

const generateFrameworkCoverageQueryMockResponse = (count = 5) => ({
  data: {
    __typename: 'Group',
    group: {
      id: 'gid://gitlab/Group/1',
      complianceFrameworkCoverageSummary: {
        totalProjects: 150,
        coveredCount: 146,
        __typename: 'ComplianceFrameworkCoverageSummary',
      },
      complianceFrameworksCoverageDetails: {
        nodes: Array.from({ length: count }).map((_, idx) => ({
          coveredCount: 6,
          id: `gid://gitlab/ComplianceManagement::FrameworkCoverageDetails/${idx}`,
          framework: {
            id: 'gid://gitlab/ComplianceManagement::Framework/79',
            name: 'Blue framework',
            color: '#6699CC',
            __typename: 'ComplianceFramework',
          },
        })),
      },
    },
  },
});

const generateFailedRequirementsQueryMockResponse = () => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/2857',
      complianceRequirementCoverage: {
        failed: 462,
        passed: 0,
        pending: 0,
        __typename: 'RequirementCoverage',
      },
      __typename: 'Group',
    },
  },
});

const generateFailedControlsQueryMockResponse = () => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/2857',
      complianceRequirementControlCoverage: {
        passed: 231,
        failed: 543,
        pending: 381,
        __typename: 'RequirementControlCoverage',
      },
      __typename: 'Group',
    },
  },
});

describe('Compliance dashboard', () => {
  let wrapper;
  const frameworkCoverageQueryMock = jest.fn().mockImplementation(() => new Promise(() => {}));
  const failedRequirementsQueryMock = jest.fn().mockImplementation(() => new Promise(() => {}));
  const failedControlsQueryMock = jest.fn().mockImplementation(() => new Promise(() => {}));

  const getDashboardConfig = () => wrapper.findComponent(DashboardLayout).props('config');

  function createComponent() {
    const apolloProvider = createMockApollo([
      [frameworkCoverageQuery, frameworkCoverageQueryMock],
      [failedRequirementsQuery, failedRequirementsQueryMock],
      [failedControlsQuery, failedControlsQueryMock],
    ]);

    wrapper = shallowMount(ComplianceDashboard, {
      apolloProvider,
      propsData: {
        groupPath: 'root',
        rootAncestorPath: 'root',
      },
    });
  }

  describe('general configuration', () => {
    const frameworkCoverage = generateFrameworkCoverageQueryMockResponse();
    const failedRequirements = generateFailedRequirementsQueryMockResponse();
    const failedControls = generateFailedControlsQueryMockResponse();

    beforeEach(() => {
      frameworkCoverageQueryMock.mockResolvedValue(frameworkCoverage);
      failedRequirementsQueryMock.mockResolvedValue(failedRequirements);
      failedControlsQueryMock.mockResolvedValue(failedControls);
      createComponent();
      return nextTick();
    });

    it('contains framework coverage panel', () => {
      expect(getDashboardConfig().panels).toContainEqual(
        expect.objectContaining({
          component: FrameworkCoverage,
          componentProps: {
            summary: {
              totalProjects:
                frameworkCoverage.data.group.complianceFrameworkCoverageSummary.totalProjects,
              coveredCount:
                frameworkCoverage.data.group.complianceFrameworkCoverageSummary.coveredCount,
              details: frameworkCoverage.data.group.complianceFrameworksCoverageDetails.nodes,
            },
            isTopLevelGroup: expect.any(Boolean),
            colorScheme: getSystemColorScheme(),
          },
        }),
      );
    });

    it('contains failed requirements panel with correct data', () => {
      expect(getDashboardConfig().panels).toContainEqual(
        expect.objectContaining({
          component: FailedRequirements,
          componentProps: {
            failedRequirements: failedRequirements.data.group.complianceRequirementCoverage,
            colorScheme: getSystemColorScheme(),
          },
        }),
      );
    });

    it('contains failed controls panel witch correct data', () => {
      expect(getDashboardConfig().panels).toContainEqual(
        expect.objectContaining({
          component: FailedControls,
          componentProps: {
            failedControls: failedControls.data.group.complianceRequirementControlCoverage,
            colorScheme: getSystemColorScheme(),
          },
        }),
      );
    });
  });

  describe('framework coverage panel', () => {
    it.each`
      frameworksCount | expectedPanelSize
      ${0}            | ${2}
      ${10}           | ${4}
      ${20}           | ${5}
    `(
      'renders correct size for $frameworksCount frameworks',
      async ({ frameworksCount, expectedPanelSize }) => {
        frameworkCoverageQueryMock.mockResolvedValue(
          generateFrameworkCoverageQueryMockResponse(frameworksCount),
        );
        createComponent();
        await waitForPromises();
        const panelConfig = getDashboardConfig().panels.find(
          (panel) => panel.component === FrameworkCoverage,
        );
        expect(panelConfig.gridAttributes.height).toBe(expectedPanelSize);
      },
    );
  });

  describe('when one of the query fails', () => {
    it.each([frameworkCoverageQueryMock, failedControlsQueryMock, failedRequirementsQueryMock])(
      'displays error message',
      async (queryMock) => {
        queryMock.mockRejectedValue(new Error('Network error'));
        createComponent();
        await waitForPromises();
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Something went wrong on our end.',
        });
      },
    );
  });
});
