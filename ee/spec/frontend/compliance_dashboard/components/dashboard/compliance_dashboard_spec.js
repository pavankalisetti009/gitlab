import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ComplianceDashboard from 'ee/compliance_dashboard/components/dashboard/compliance_dashboard.vue';
import FrameworkCoverage from 'ee/compliance_dashboard/components/dashboard/framework_coverage.vue';
import FailedRequirements from 'ee/compliance_dashboard/components/dashboard/failed_requirements.vue';
import FailedControls from 'ee/compliance_dashboard/components/dashboard/failed_controls.vue';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import frameworkCoverageQuery from 'ee/compliance_dashboard/components/dashboard/graphql/framework_coverage.query.graphql';
import frameworkCoverageQuery from 'ee/compliance_dashboard/components/dashboard/graphql/framework_coverage.query.gql';
import failedRequirementsQuery from 'ee/compliance_dashboard/components/dashboard/graphql/failed_requirements.query.gql';
import failedControlsQuery from 'ee/compliance_dashboard/components/dashboard/graphql/failed_controls.query.gql';

Vue.use(VueApollo);

const generateMockResponse = (count = 5) => ({
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

describe('Compliance dashboard', () => {
  let wrapper;
  const frameworkCoverageQueryMock = jest.fn();

  const getDashboardConfig = () => wrapper.findComponent(DashboardLayout).props('config');

  function createComponent() {
    const apolloProvider = createMockApollo([
      [frameworkCoverageQuery, frameworkCoverageQueryMock],
      [failedRequirementsQuery, Promise.resolve()],
      [failedControlsQuery, Promise.resolve()],
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
    beforeEach(() => {
      frameworkCoverageQueryMock.mockResolvedValue(generateMockResponse());
      createComponent();
      return nextTick();
    });

    it('contains framework coverage panel', () => {
      expect(getDashboardConfig().panels).toContainEqual(
        expect.objectContaining({
          component: FrameworkCoverage,
          componentProps: {
            summary: expect.anything(),
            isTopLevelGroup: expect.any(Boolean),
            colorScheme: undefined,
          },
        }),
      );
    });

    it('contains failed requirements panel', () => {
      expect(getDashboardConfig().panels).toContainEqual(
        expect.objectContaining({
          component: FailedRequirements,
          componentProps: {
            failedRequirements: expect.anything(),
            colorScheme: undefined,
          },
        }),
      );
    });

    it('contains failed controls panel', () => {
      expect(getDashboardConfig().panels).toContainEqual(
        expect.objectContaining({
          component: FailedControls,
          componentProps: {
            failedControls: expect.anything(),
            colorScheme: undefined,
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
        frameworkCoverageQueryMock.mockResolvedValue(generateMockResponse(frameworksCount));
        createComponent();
        await waitForPromises();
        const panelConfig = getDashboardConfig().panels.find(
          (panel) => panel.component === FrameworkCoverage,
        );
        expect(panelConfig.gridAttributes.height).toBe(expectedPanelSize);
      },
    );
  });
});
