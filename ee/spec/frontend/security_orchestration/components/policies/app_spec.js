import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import ListHeader from 'ee/security_orchestration/components/policies/list_header.vue';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import App from 'ee/security_orchestration/components/policies/app.vue';
import {
  MAX_SCAN_EXECUTION_ACTION_COUNT,
  MAX_SCAN_EXECUTION_POLICY_SCHEDULED_RULES_COUNT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import {
  DEPRECATED_CUSTOM_SCAN_PROPERTY,
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
} from 'ee/security_orchestration/components/policies/constants';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import * as urlUtils from '~/lib/utils/url_utility';
import {
  mockGroupPipelineExecutionPolicyCombinedList,
  mockGroupPipelineExecutionSchedulePolicyCombinedList,
  mockProjectPipelineExecutionPolicyCombinedList,
  mockProjectPipelineExecutionSchedulePolicyCombinedList,
} from '../../mocks/mock_pipeline_execution_policy_data';
import { mockProjectVulnerabilityManagementPolicyCombinedList } from '../../mocks/mock_vulnerability_management_policy_data';
import {
  mockLinkedSppItemsResponse,
  groupSecurityPolicies,
  projectSecurityPolicies,
  groupByType,
  defaultPageInfo,
} from '../../mocks/mock_apollo';
import {
  mockGroupScanExecutionPolicyCombinedList,
  mockProjectScanExecutionPolicyCombinedList,
  mockScanExecutionPoliciesWithSameNamesDifferentSourcesResponse,
} from '../../mocks/mock_scan_execution_policy_data';
import {
  mockGroupScanResultPolicyCombinedList,
  mockProjectScanResultPolicyCombinedList,
} from '../../mocks/mock_scan_result_policy_data';

jest.mock('~/alert');

const groupPolicyList = [
  mockProjectVulnerabilityManagementPolicyCombinedList,
  mockGroupPipelineExecutionPolicyCombinedList,
  mockGroupPipelineExecutionSchedulePolicyCombinedList,
  mockGroupScanResultPolicyCombinedList,
  mockGroupScanExecutionPolicyCombinedList,
];

const projectPolicyList = [
  mockProjectVulnerabilityManagementPolicyCombinedList,
  mockProjectPipelineExecutionPolicyCombinedList,
  mockProjectPipelineExecutionSchedulePolicyCombinedList,
  mockProjectScanResultPolicyCombinedList,
  mockProjectScanExecutionPolicyCombinedList,
];

const groupSecurityPoliciesSpy = groupSecurityPolicies(groupPolicyList);
const projectSecurityPoliciesSpy = projectSecurityPolicies(projectPolicyList);

const flattenedProjectSecurityPolicies = groupByType(projectPolicyList);

const linkedSppItemsResponseSpy = mockLinkedSppItemsResponse();
const defaultRequestHandlers = {
  linkedSppItemsResponse: linkedSppItemsResponseSpy,
  groupSecurityPolicies: groupSecurityPoliciesSpy,
  projectSecurityPolicies: projectSecurityPoliciesSpy,
};

const expectedPolicyList = {
  [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]:
    flattenedProjectSecurityPolicies[POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter],
  [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]:
    flattenedProjectSecurityPolicies[POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter],
  [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]:
    flattenedProjectSecurityPolicies[POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter],
  [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION_SCHEDULE.value]:
    flattenedProjectSecurityPolicies[
      POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.urlParameter
    ],
  [POLICY_TYPE_FILTER_OPTIONS.VULNERABILITY_MANAGEMENT.value]:
    flattenedProjectSecurityPolicies[
      POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.urlParameter
    ],
};

describe('App', () => {
  let wrapper;
  let requestHandlers;
  const namespacePath = 'path/to/project/or/group';

  const createWrapper = ({ assignedPolicyProject = null, handlers = {}, provide = {} } = {}) => {
    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = shallowMountExtended(App, {
      provide: {
        assignedPolicyProject,
        enabledExperiments: ['pipeline_execution_schedule_policy'],
        namespacePath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        maxScanExecutionPolicyActions: MAX_SCAN_EXECUTION_ACTION_COUNT,
        maxScanExecutionPolicySchedules: MAX_SCAN_EXECUTION_POLICY_SCHEDULED_RULES_COUNT,
        ...provide,
      },
      apolloProvider: createMockApollo(
        [
          [getSppLinkedProjectsGroups, requestHandlers.linkedSppItemsResponse],

          [groupSecurityPoliciesQuery, requestHandlers.groupSecurityPolicies],
          [projectSecurityPoliciesQuery, requestHandlers.projectSecurityPolicies],
        ],
        {},
        { typePolicies: { ScanExecutionPolicy: { keyFields: ['name', 'updatedAt'] } } },
      ),
    });
  };

  const findPoliciesHeader = () => wrapper.findComponent(ListHeader);
  const findPoliciesList = () => wrapper.findComponent(ListComponent);

  describe('loading', () => {
    it('renders the policies list correctly', () => {
      createWrapper();
      expect(findPoliciesList().props('isLoadingPolicies')).toBe(true);
    });
  });

  describe('default', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders the policies list correctly', () => {
      expect(findPoliciesList().props()).toEqual(
        expect.objectContaining({
          shouldUpdatePolicyList: false,
          hasPolicyProject: false,
          selectedPolicySource: POLICY_SOURCE_OPTIONS.ALL.value,
          selectedPolicyType: POLICY_TYPE_FILTER_OPTIONS.ALL.value,
        }),
      );

      expect(findPoliciesList().props('policiesByType')).toEqual(expectedPolicyList);
    });

    it('renders the policy header correctly', () => {
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toBe(false);
    });

    it('fetches linked SPP items', () => {
      expect(linkedSppItemsResponseSpy).toHaveBeenCalledTimes(1);
    });

    it('updates the policy list when a the security policy project is changed', async () => {
      expect(projectSecurityPoliciesSpy).toHaveBeenCalledTimes(1);
      expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(false);
      expect(findPoliciesList().props('hasPolicyProject')).toBe(false);
      findPoliciesHeader().vm.$emit('update-policy-list', {
        shouldUpdatePolicyList: true,
        hasPolicyProject: true,
      });
      await nextTick();
      expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(true);
      expect(findPoliciesList().props('hasPolicyProject')).toBe(true);
      expect(projectSecurityPoliciesSpy).toHaveBeenCalledTimes(2);
    });
  });

  it('renders scan execution policies with different sources and same name', async () => {
    const projectSecurityPoliciesWitSameNameSpy = projectSecurityPolicies([
      ...projectPolicyList,
      mockScanExecutionPoliciesWithSameNamesDifferentSourcesResponse[1],
    ]);

    createWrapper({
      handlers: { projectSecurityPolicies: projectSecurityPoliciesWitSameNameSpy },
    });
    await waitForPromises();

    expect(findPoliciesList().props('policiesByType').SCAN_EXECUTION[0].source).toEqual({
      __typename: 'ProjectSecurityPolicySource',
      project: {
        fullPath: 'project/path',
      },
    });

    expect(findPoliciesList().props('policiesByType').SCAN_EXECUTION[1].source).toEqual({
      __typename: 'GroupSecurityPolicySource',
      inherited: true,
      namespace: {
        __typename: 'Namespace',
        id: '1',
        fullPath: 'parent-group-path',
        name: 'parent-group-name',
      },
    });
  });

  it('renders correctly when a policy project is linked', async () => {
    createWrapper({ assignedPolicyProject: { id: '1' } });
    await nextTick();

    expect(findPoliciesList().props('hasPolicyProject')).toBe(true);
  });

  describe('network errors', () => {
    beforeEach(async () => {
      const errorHandlers = Object.keys(defaultRequestHandlers).reduce((acc, curr) => {
        acc[curr] = jest.fn().mockRejectedValue();
        return acc;
      }, {});
      createWrapper({ handlers: errorHandlers });
      await waitForPromises();
    });

    it('shows an alert', () => {
      expect(createAlert).toHaveBeenCalledTimes(2);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong, unable to fetch policies',
      });
    });

    it('uses an empty array as the default value', () => {
      expect(findPoliciesList().props()).toEqual(
        expect.objectContaining({
          linkedSppItems: [],
          policiesByType: {
            APPROVAL: [],
            PIPELINE_EXECUTION: [],
            PIPELINE_EXECUTION_SCHEDULE: [],
            SCAN_EXECUTION: [],
            VULNERABILITY_MANAGEMENT: [],
          },
        }),
      );
    });
  });

  describe('group-level policies', () => {
    beforeEach(async () => {
      createWrapper({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
      await waitForPromises();
    });

    it('does not fetch linked SPP items', () => {
      expect(linkedSppItemsResponseSpy).toHaveBeenCalledTimes(0);
    });
  });

  describe('invalid policies', () => {
    it('updates "hasInvalidPolicies" when there are deprecated properties in scan result policies that are not "type: scan_result_policy"', async () => {
      const securityPolicy = projectPolicyList[3];
      const { policyAttributes } = securityPolicy;
      createWrapper({
        handlers: {
          projectSecurityPolicies: projectSecurityPolicies([
            {
              ...securityPolicy,
              policyAttributes: {
                ...policyAttributes,
                deprecatedProperties: ['test', 'test1'],
              },
            },
          ]),
        },
      });
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(true);
    });

    it('does not emit that a policy is invalid when there are deprecated properties in scan result policies that are "type: scan_result_policy"', async () => {
      createWrapper();
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
    });
  });

  describe('deprecated custom scan action policies', () => {
    it('updates "hasDeprecatedCustomScanPolicies" when there are deprecated properties in scan execution policies', async () => {
      const securityPolicy = projectPolicyList[4];
      const { policyAttributes } = securityPolicy;
      createWrapper({
        handlers: {
          projectSecurityPolicies: projectSecurityPolicies([
            {
              ...securityPolicy,
              policyAttributes: {
                ...policyAttributes,
                deprecatedProperties: [DEPRECATED_CUSTOM_SCAN_PROPERTY],
              },
            },
          ]),
        },
      });
      expect(findPoliciesHeader().props('hasDeprecatedCustomScanPolicies')).toEqual(false);
      await waitForPromises();
      expect(findPoliciesHeader().props('hasDeprecatedCustomScanPolicies')).toEqual(true);
    });

    it('does not emit that a policy is invalid when there are no deprecated properties', async () => {
      createWrapper();
      await waitForPromises();
      expect(findPoliciesHeader().props('hasDeprecatedCustomScanPolicies')).toEqual(false);
    });
  });

  describe('policy list', () => {
    it('loads policy list without scheduled policies', async () => {
      createWrapper();

      await waitForPromises();

      expect(requestHandlers.projectSecurityPolicies).toHaveBeenCalledTimes(1);

      expect(findPoliciesList().props('policiesByType')).toEqual(expectedPolicyList);
    });

    it('loads full policy list', async () => {
      createWrapper({
        provide: {
          enabledExperiments: ['pipeline_execution_schedule_policy'],
        },
      });
      await waitForPromises();

      expect(requestHandlers.projectSecurityPolicies).toHaveBeenCalledTimes(1);

      expect(findPoliciesList().props()).toEqual(
        expect.objectContaining({
          shouldUpdatePolicyList: false,
          hasPolicyProject: false,
          selectedPolicySource: POLICY_SOURCE_OPTIONS.ALL.value,
          selectedPolicyType: POLICY_TYPE_FILTER_OPTIONS.ALL.value,
        }),
      );

      expect(findPoliciesList().props('policiesByType')).toEqual({
        ...expectedPolicyList,
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION_SCHEDULE.value]:
          flattenedProjectSecurityPolicies[
            POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.urlParameter
          ],
      });
    });
  });

  describe('filtering policies', () => {
    describe.each`
      emittedType                      | expectedType
      ${'APPROVAL'}                    | ${'APPROVAL_POLICY'}
      ${'SCAN_EXECUTION'}              | ${'SCAN_EXECUTION_POLICY'}
      ${'PIPELINE_EXECUTION'}          | ${'PIPELINE_EXECUTION_POLICY'}
      ${'PIPELINE_EXECUTION_SCHEDULE'} | ${'PIPELINE_EXECUTION_SCHEDULE_POLICY'}
      ${'VULNERABILITY_MANAGEMENT'}    | ${'VULNERABILITY_MANAGEMENT_POLICY'}
    `('filters policies by type', ({ emittedType, expectedType }) => {
      it('filters policies by type', async () => {
        createWrapper();

        await waitForPromises();

        await findPoliciesList().vm.$emit('update-policy-type', emittedType);

        expect(requestHandlers.projectSecurityPolicies).toHaveBeenNthCalledWith(2, {
          fullPath: namespacePath,
          relationship: POLICY_SOURCE_OPTIONS.ALL.value,
          after: '',
          before: '',
          first: 50,
          type: expectedType,
        });
      });

      it('sets correct selected from query type', async () => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(emittedType.toLowerCase());

        createWrapper();

        await waitForPromises();

        expect(requestHandlers.projectSecurityPolicies).toHaveBeenCalledWith({
          fullPath: namespacePath,
          relationship: POLICY_SOURCE_OPTIONS.ALL.value,
          after: '',
          before: '',
          first: 50,
          type: expectedType,
        });
      });
    });
  });

  describe('pagination', () => {
    it('fetches next page when policy list is changed to a next page', async () => {
      createWrapper({
        handlers: {
          projectSecurityPolicies: projectSecurityPolicies(projectPolicyList, {
            ...defaultPageInfo,
            endCursor: 'next',
          }),
        },
      });
      await waitForPromises();

      await findPoliciesList().vm.$emit('next-page');

      expect(requestHandlers.projectSecurityPolicies).toHaveBeenNthCalledWith(2, {
        fullPath: namespacePath,
        relationship: POLICY_SOURCE_OPTIONS.ALL.value,
        after: 'next',
        before: '',
        first: 50,
      });
    });

    it('fetches previous page when policy list is changed to a previous page', async () => {
      createWrapper({
        handlers: {
          projectSecurityPolicies: projectSecurityPolicies(projectPolicyList, {
            ...defaultPageInfo,
            startCursor: 'previous',
          }),
        },
      });
      await waitForPromises();

      await findPoliciesList().vm.$emit('prev-page');

      expect(requestHandlers.projectSecurityPolicies).toHaveBeenNthCalledWith(2, {
        fullPath: namespacePath,
        relationship: POLICY_SOURCE_OPTIONS.ALL.value,
        after: '',
        before: 'previous',
        first: null,
        last: 50,
      });
    });
  });
});
