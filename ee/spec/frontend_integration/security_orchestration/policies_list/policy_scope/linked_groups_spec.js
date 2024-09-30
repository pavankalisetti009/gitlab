import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  projectScanExecutionPolicies,
  groupScanExecutionPolicies,
  projectScanResultPolicies,
  groupScanResultPolicies,
  projectPipelineResultPolicies,
  groupPipelineResultPolicies,
  mockLinkedSppItemsResponse,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { mockScanExecutionPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';
import { mockScanResultPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import { mockPipelineExecutionPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import App from 'ee/security_orchestration/components/policies/app.vue';
import projectScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_result_policies.query.graphql';
import projectPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_pipeline_execution_policies.query.graphql';
import groupPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_pipeline_execution_policies.query.graphql';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import ScopeInfoRow from 'ee/security_orchestration/components/policy_drawer/scope_info_row.vue';
import ListComponentScope from 'ee/security_orchestration/components/policies/list_component_scope.vue';
import GroupsToggleList from 'ee/security_orchestration/components/policy_drawer/groups_toggle_list.vue';
import { DEFAULT_PROVIDE } from '../mocks';

Vue.use(VueApollo);

const includingGroups = [
  {
    __typename: 'Group',
    id: 'gid://gitlab/Group/98',
    name: 'gitlab-policies-sub',
    fullPath: 'gitlab-policies/gitlab-policies-sub',
  },
  {
    __typename: 'Group',
    id: 'gid://gitlab/Group/99',
    name: 'gitlab-policies-sub-2',
    fullPath: 'gitlab-policies/gitlab-policies-sub-2',
  },
];

const excludingProjects = [
  {
    __typename: 'Project',
    fullPath: 'gitlab-policies/test',
    id: 'gid://gitlab/Project/37',
    name: 'test',
  },
];

const generateMockResponse = (index, basis) => ({
  ...basis[index],
  policyScope: {
    ...basis[index].policyScope,
    includingGroups: {
      nodes: includingGroups,
      pageInfo: {},
    },
    excludingProjects: {
      nodes: excludingProjects,
      pageInfo: {},
    },
  },
});

const mockPipelineExecutionPoliciesProjectResponse = generateMockResponse(
  0,
  mockPipelineExecutionPoliciesResponse,
);
const mockPipelineExecutionPoliciesGroupResponse = generateMockResponse(
  1,
  mockPipelineExecutionPoliciesResponse,
);

const mockScanExecutionPoliciesProjectResponse = generateMockResponse(
  0,
  mockScanExecutionPoliciesResponse,
);
const mockScanExecutionPoliciesGroupResponse = generateMockResponse(
  1,
  mockScanExecutionPoliciesResponse,
);

const mockScanResultPoliciesProjectResponse = generateMockResponse(
  0,
  mockScanResultPoliciesResponse,
);
const mockScanResultPoliciesGroupResponse = generateMockResponse(1, mockScanResultPoliciesResponse);

/**
 * New mocks for policy scope including linked groups on project level
 * @type {jest.Mock<any, any, any>}
 */
const newProjectPipelineExecutionPoliciesSpy = projectPipelineResultPolicies([
  mockPipelineExecutionPoliciesProjectResponse,
  mockPipelineExecutionPoliciesGroupResponse,
]);

const newProjectScanExecutionPoliciesSpy = projectScanExecutionPolicies([
  mockScanExecutionPoliciesProjectResponse,
  mockScanExecutionPoliciesGroupResponse,
]);
const newProjectScanResultPoliciesSpy = projectScanResultPolicies([
  mockScanResultPoliciesProjectResponse,
  mockScanResultPoliciesGroupResponse,
]);

/**
 * New mocks for policy scope including linked groups on group level
 * @type {jest.Mock<any, any, any>}
 */
const newGroupPipelineExecutionPoliciesSpy = groupPipelineResultPolicies([
  mockPipelineExecutionPoliciesProjectResponse,
  mockPipelineExecutionPoliciesGroupResponse,
]);

const newGroupScanExecutionPoliciesSpy = groupScanExecutionPolicies([
  mockScanExecutionPoliciesProjectResponse,
  mockScanExecutionPoliciesGroupResponse,
]);
const newGroupScanResultPoliciesSpy = groupScanResultPolicies([
  mockScanResultPoliciesProjectResponse,
  mockScanResultPoliciesGroupResponse,
]);

const defaultRequestHandlers = {
  projectScanExecutionPolicies: newProjectScanExecutionPoliciesSpy,
  groupScanExecutionPolicies: newGroupScanExecutionPoliciesSpy,
  projectScanResultPolicies: newProjectScanResultPoliciesSpy,
  groupScanResultPolicies: newGroupScanResultPoliciesSpy,
  projectPipelineExecutionPolicies: newProjectPipelineExecutionPoliciesSpy,
  groupPipelineExecutionPolicies: newGroupPipelineExecutionPoliciesSpy,
  linkedSppItemsResponse: mockLinkedSppItemsResponse(),
};

describe('Policies List policy scope', () => {
  let wrapper;
  let requestHandlers;

  const createWrapper = ({ handlers = [], provide = {} } = {}) => {
    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = mountExtended(App, {
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
      },
      apolloProvider: createMockApollo([
        [projectScanExecutionPoliciesQuery, requestHandlers.projectScanExecutionPolicies],
        [groupScanExecutionPoliciesQuery, requestHandlers.groupScanExecutionPolicies],
        [projectScanResultPoliciesQuery, requestHandlers.projectScanResultPolicies],
        [groupScanResultPoliciesQuery, requestHandlers.groupScanResultPolicies],
        [projectPipelineExecutionPoliciesQuery, requestHandlers.projectPipelineExecutionPolicies],
        [groupPipelineExecutionPoliciesQuery, requestHandlers.groupPipelineExecutionPolicies],
        [getSppLinkedProjectsGroups, requestHandlers.linkedSppItemsResponse],
      ]),
    });
  };

  const findTable = () => wrapper.findByTestId('policies-list');
  const findScopeInfoRow = () => wrapper.findComponent(ScopeInfoRow);
  const findAllListComponentScope = () => wrapper.findAllComponents(ListComponentScope);
  const findGroupsToggleList = () => wrapper.findComponent(GroupsToggleList);

  const openDrawer = async (rows) => {
    findTable().vm.$emit('row-selected', rows);
    await nextTick();
    await waitForPromises();
  };

  const expectDrawerScopeInfoRow = () => {
    expect(findGroupsToggleList().exists()).toBe(true);
    expect(findGroupsToggleList().props('groups')).toEqual(includingGroups);
    expect(findGroupsToggleList().props('projects')).toEqual(excludingProjects);
  };

  describe('project level', () => {
    describe('group policy scope for $policyType', () => {
      it.each`
        policyType              | policyScopeRowIndex | selectedRow
        ${'Pipeline execution'} | ${4}                | ${mockPipelineExecutionPoliciesProjectResponse}
        ${'Scan execution'}     | ${1}                | ${mockScanExecutionPoliciesProjectResponse}
        ${'Scan Result'}        | ${2}                | ${mockScanResultPoliciesProjectResponse}
      `(
        'scoped to itself when project is not SPP for $policyType',
        async ({ policyScopeRowIndex, selectedRow }) => {
          createWrapper({
            provide: {
              glFeatures: {
                policyGroupScopeProject: true,
              },
            },
          });

          await waitForPromises();
          expect(findAllListComponentScope().at(policyScopeRowIndex).text()).toBe('This project');

          await openDrawer([selectedRow]);

          expect(findScopeInfoRow().text()).toContain('This policy is applied to current project.');
        },
      );

      it.each`
        policyType              | policyScopeRowIndex | selectedRow                                     | expectedResult
        ${'Pipeline execution'} | ${4}                | ${mockPipelineExecutionPoliciesProjectResponse} | ${'All projects in linked groups (2 groups)'}
        ${'Scan execution'}     | ${1}                | ${mockScanExecutionPoliciesProjectResponse}     | ${'All projects in linked groups (2 groups)'}
        ${'Scan Result'}        | ${2}                | ${mockScanResultPoliciesProjectResponse}        | ${'All projects in linked groups (2 groups)'}
      `(
        'scoped to linked groups when project is an SPP for $policyType',
        async ({ policyScopeRowIndex, selectedRow, expectedResult }) => {
          createWrapper({
            handlers: {
              linkedSppItemsResponse: mockLinkedSppItemsResponse({
                groups: includingGroups,
                namespaces: includingGroups,
              }),
            },
            provide: {
              glFeatures: {
                policyGroupScopeProject: true,
              },
            },
          });

          await waitForPromises();

          expect(findAllListComponentScope().at(policyScopeRowIndex).text()).toBe(expectedResult);

          await openDrawer([selectedRow]);

          expectDrawerScopeInfoRow();
        },
      );
    });
  });

  describe('group level', () => {
    it.each`
      policyType              | policyScopeRowIndex | selectedRow                                     | expectedResult
      ${'Pipeline execution'} | ${4}                | ${mockPipelineExecutionPoliciesProjectResponse} | ${'All projects in linked groups (2 groups)'}
      ${'Scan execution'}     | ${1}                | ${mockScanExecutionPoliciesProjectResponse}     | ${'All projects in linked groups (2 groups)'}
      ${'Scan Result'}        | ${2}                | ${mockScanResultPoliciesProjectResponse}        | ${'All projects in linked groups (2 groups)'}
    `(
      'scoped to linked groups on a group level for $policyType',
      async ({ policyScopeRowIndex, selectedRow, expectedResult }) => {
        createWrapper({
          provide: {
            namespaceType: NAMESPACE_TYPES.GROUP,
            glFeatures: {
              policyGroupScope: true,
            },
          },
        });

        await waitForPromises();

        expect(findAllListComponentScope().at(policyScopeRowIndex).text()).toBe(expectedResult);

        await openDrawer([selectedRow]);

        expectDrawerScopeInfoRow();
      },
    );
  });
});
