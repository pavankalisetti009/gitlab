import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { isLoggedIn } from '~/lib/utils/common_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemDetail from '~/work_items/components/work_item_detail.vue';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import workItemUpdatedSubscription from '~/work_items/graphql/work_item_updated.subscription.graphql';
import workspacePermissionsQuery from '~/work_items/graphql/workspace_permissions.query.graphql';
import getAllowedWorkItemChildTypes from '~/work_items/graphql/work_item_allowed_children.query.graphql';
import DuoWorkflowAction from 'ee_component/ai/components/duo_workflow_action.vue';
import { buildApiUrl } from '~/api/api_utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

import {
  workItemByIidResponseFactory,
  mockProjectPermissionsQueryResponse,
  allowedChildrenTypesResponse,
} from 'ee_else_ce_jest/work_items/mock_data';

jest.mock('~/lib/utils/common_utils');
jest.mock('~/api/api_utils');
jest.mock('~/graphql_shared/utils');

describe('EE WorkItemDetail component', () => {
  let wrapper;

  Vue.use(VueApollo);

  const workItemByIidQueryResponse = workItemByIidResponseFactory({
    canUpdate: true,
    canDelete: true,
  });
  const successHandler = jest.fn().mockResolvedValue(workItemByIidQueryResponse);
  const workItemUpdatedSubscriptionHandler = jest
    .fn()
    .mockResolvedValue({ data: { workItemUpdated: null } });
  const workspacePermissionsAllowedHandler = jest
    .fn()
    .mockResolvedValue(mockProjectPermissionsQueryResponse());
  const allowedChildrenTypesHandler = jest.fn().mockResolvedValue(allowedChildrenTypesResponse);

  const createComponent = ({
    workItemIid = '1',
    handler = successHandler,
    glFeatures = {},
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemDetail, {
      apolloProvider: createMockApollo([
        [workItemByIidQuery, handler],
        [workItemUpdatedSubscription, workItemUpdatedSubscriptionHandler],
        [getAllowedWorkItemChildTypes, allowedChildrenTypesHandler],
        [workspacePermissionsQuery, workspacePermissionsAllowedHandler],
      ]),
      isLoggedIn: isLoggedIn(),
      propsData: {
        workItemIid,
      },
      provide: {
        glFeatures: {
          workItemsAlpha: true,
          ...glFeatures,
        },
        hasSubepicsFeature: true,
        hasLinkedItemsEpicsFeature: true,
        fullPath: 'group/project',
        groupPath: 'group',
        reportAbusePath: '/report/abuse/path',
      },
      mocks: {
        $router: true,
      },
      stubs: {
        WorkItemVulnerabilities: true,
        DuoWorkflowAction: true,
      },
    });
  };

  beforeEach(() => {
    isLoggedIn.mockReturnValue(true);
    getIdFromGraphQLId.mockReturnValue(123);
    buildApiUrl.mockReturnValue('/api/v4/ai/duo_workflows/workflows');
  });

  const findVulnerabilitiesWidget = () =>
    wrapper.findComponentByTestId('work-item-vulnerabilities');
  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  describe('vulnerabilities widget', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('shows vulnerabilities widget', () => {
      expect(findVulnerabilitiesWidget().exists()).toBe(true);
    });
  });

  describe('Duo Workflow Action', () => {
    beforeEach(async () => {
      createComponent({ glFeatures: { aiDuoAgentIssueToMr: true } });
      await waitForPromises();
    });

    it('shows DuoWorkflowAction component', () => {
      expect(findDuoWorkflowAction().exists()).toBe(true);
    });

    it('passes correct props to DuoWorkflowAction', () => {
      const duoWorkflowAction = findDuoWorkflowAction();
      const { workItem } = workItemByIidQueryResponse.data.workspace;

      expect(duoWorkflowAction.props()).toMatchObject({
        projectId: 123,
        title: 'Generate MR with Duo',
        hoverMessage: 'Generate merge request with Duo',
        goal: workItem.webUrl,
        workflowDefinition: 'issue_to_merge_request',
        agentPrivileges: [1, 2, 3, 4, 5],
        duoWorkflowInvokePath: '/api/v4/ai/duo_workflows/workflows',
        size: 'medium',
      });
    });

    it('calls getIdFromGraphQLId with the project ID', () => {
      expect(getIdFromGraphQLId).toHaveBeenCalledWith(
        workItemByIidQueryResponse.data.workspace.workItem.project.id,
      );
    });

    it('calls buildApiUrl with the correct path', () => {
      expect(buildApiUrl).toHaveBeenCalledWith('/api/:version/ai/duo_workflows/workflows');
    });

    describe('when aiDuoAgentIssueToMr feature flag is disabled', () => {
      beforeEach(async () => {
        createComponent({ glFeatures: { aiDuoAgentIssueToMr: false } });
        await waitForPromises();
      });

      it('does not show DuoWorkflowAction component', () => {
        expect(findDuoWorkflowAction().exists()).toBe(false);
      });
    });
  });
});
