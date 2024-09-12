import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { SECURITY_POLICY_ACTIONS } from 'ee/security_orchestration/components/policy_editor/constants';
import { goToPolicyMR } from 'ee/security_orchestration/components/policy_editor/utils';
import getSecurityPolicyProjectSub from 'ee/security_orchestration/graphql/queries/security_policy_project_created.subscription.graphql';
import EditorWrapper from 'ee/security_orchestration/components/policy_editor/editor_wrapper.vue';
import PipelineExecutionPolicyEditor from 'ee/security_orchestration/components/policy_editor/pipeline_execution/editor_component.vue';
import ScanExecutionPolicyEditor from 'ee/security_orchestration/components/policy_editor/scan_execution/editor_component.vue';
import ScanResultPolicyEditor from 'ee/security_orchestration/components/policy_editor/scan_result/editor_component.vue';
import VulnerabilityManagementPolicyEditor from 'ee/security_orchestration/components/policy_editor/vulnerability_management/editor_component.vue';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import {
  mockDastScanExecutionManifest,
  mockDastScanExecutionObject,
} from '../../mocks/mock_scan_execution_policy_data';

jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  goToPolicyMR: jest.fn().mockResolvedValue(),
}));

Vue.use(VueApollo);

describe('EditorWrapper component', () => {
  let wrapper;
  const getSecurityPolicyProjectSubscriptionErrorHandlerMock = jest.fn().mockResolvedValue({
    data: {
      securityPolicyProjectCreated: {
        project: null,
        status: null,
        errorMessage: 'error',
      },
    },
  });

  const getSecurityPolicyProjectSubscriptionHandlerMock = jest.fn().mockResolvedValue({
    data: {
      securityPolicyProjectCreated: {
        project: {
          name: 'New project',
          fullPath: 'path/to/new-project',
          id: '01',
          branch: {
            rootRef: 'main',
          },
        },
        status: null,
        errorMessage: '',
      },
    },
  });

  const defaultProjectPath = 'path/to/project';
  const existingAssignedPolicyProject = {
    branch: 'main',
    fullPath: 'path/to/new-project',
  };

  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findPipelineExecutionPolicyEditor = () =>
    wrapper.findComponent(PipelineExecutionPolicyEditor);
  const findScanExecutionPolicyEditor = () => wrapper.findComponent(ScanExecutionPolicyEditor);
  const findScanResultPolicyEditor = () => wrapper.findComponent(ScanResultPolicyEditor);
  const findVulnerabilityManagementPolicyEditor = () =>
    wrapper.findComponent(VulnerabilityManagementPolicyEditor);

  const factory = ({
    propsData = {},
    provide = {},
    subscriptionMock = getSecurityPolicyProjectSubscriptionHandlerMock,
  } = {}) => {
    wrapper = shallowMountExtended(EditorWrapper, {
      propsData: {
        selectedPolicyType: 'container',
        ...propsData,
      },
      provide: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        namespacePath: defaultProjectPath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        policyType: undefined,
        ...provide,
      },
      apolloProvider: createMockApollo([[getSecurityPolicyProjectSub, subscriptionMock]]),
    });
  };

  describe('when there is no existingPolicy', () => {
    describe('project-level', () => {
      beforeEach(factory);

      it.each`
        component        | findComponent
        ${'error alert'} | ${findErrorAlert}
      `('does not display the $component', ({ findComponent }) => {
        expect(findComponent().exists()).toBe(false);
      });

      it('renders the policy editor component', () => {
        expect(findScanExecutionPolicyEditor().props('existingPolicy')).toBe(null);
      });

      it('shows an alert when "error" is emitted from the component', async () => {
        const errorMessage = 'test';
        await findScanExecutionPolicyEditor().vm.$emit('error', errorMessage);
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe(errorMessage);
      });

      it('shows an alert with details when multiline "error" is emitted from the component', async () => {
        const errorMessages = 'title\ndetail1';
        await findScanExecutionPolicyEditor().vm.$emit('error', errorMessages);
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe('title');
        expect(alert.text()).toBe('detail1');
      });

      it.each`
        policyTypeId                                                   | findComponent
        ${POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.value}       | ${findPipelineExecutionPolicyEditor}
        ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value}           | ${findScanExecutionPolicyEditor}
        ${POLICY_TYPE_COMPONENT_OPTIONS.approval.value}                | ${findScanResultPolicyEditor}
        ${POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.value} | ${findVulnerabilityManagementPolicyEditor}
      `(
        'renders the policy editor of type $policyType when selected',
        ({ findComponent, policyTypeId }) => {
          factory({ propsData: { selectedPolicyType: policyTypeId } });
          const component = findComponent();
          expect(component.exists()).toBe(true);
          expect(component.props('isEditing')).toBe(false);
        },
      );
    });
  });

  describe('when there is existingPolicy attached', () => {
    beforeEach(() => {
      factory({ provide: { existingPolicy: mockDastScanExecutionObject } });
    });

    it('renders the policy editor for editing', () => {
      expect(findScanExecutionPolicyEditor().props('isEditing')).toBe(true);
    });
  });

  describe('subscription', () => {
    it('does not subscribe to the newlyCreatedPolicyProject subscription w/ securityPoliciesProjectBackgroundWorker false', () => {
      factory();
      expect(getSecurityPolicyProjectSubscriptionHandlerMock).not.toHaveBeenCalled();
    });

    it('subscribes to the newlyCreatedPolicyProject subscription w/ securityPoliciesProjectBackgroundWorker true', () => {
      factory({ provide: { glFeatures: { securityPoliciesProjectBackgroundWorker: true } } });
      expect(getSecurityPolicyProjectSubscriptionHandlerMock).toHaveBeenCalledWith({
        fullPath: defaultProjectPath,
      });
    });

    it('updates the project when the subscription fulfills with a project w/ securityPoliciesProjectBackgroundWorker true', async () => {
      factory({
        provide: {
          namespacePath: 'path/to/namespace',
          glFeatures: { securityPoliciesProjectBackgroundWorker: true },
        },
      });
      await waitForPromises();
      expect(findScanExecutionPolicyEditor().props('assignedPolicyProject')).toEqual({
        name: 'New project',
        fullPath: 'path/to/new-project',
        id: '01',
        branch: 'main',
      });
      expect(findScanExecutionPolicyEditor().props('errorMessages')).toBe(undefined);
      expect(goToPolicyMR).not.toHaveBeenCalled();
    });

    it('passes the errors when the the subscription fails with a project w/ securityPoliciesProjectBackgroundWorker true', async () => {
      factory({
        provide: { glFeatures: { securityPoliciesProjectBackgroundWorker: true } },
        subscriptionMock: getSecurityPolicyProjectSubscriptionErrorHandlerMock,
      });
      await waitForPromises();
      expect(findScanExecutionPolicyEditor().props('assignedPolicyProject')).toEqual({
        branch: '',
        fullPath: '',
      });
      expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([]);
    });
  });

  describe('creating an MR with the policy changes', () => {
    describe('without an assigned policy project', () => {
      it('does not make the request to create the MR without an assigned policy project', async () => {
        await factory({
          provide: { glFeatures: { securityPoliciesProjectBackgroundWorker: true } },
          subscriptionMock: getSecurityPolicyProjectSubscriptionErrorHandlerMock,
        });
        findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
        });
        await waitForPromises();
        expect(goToPolicyMR).not.toHaveBeenCalled();
      });
    });

    describe('existing policy', () => {
      it.each`
        status                            | action
        ${'to update an existing policy'} | ${SECURITY_POLICY_ACTIONS.REPLACE}
        ${'to delete an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE}
      `('makes the request to "goToPolicyMR" $status', async ({ action }) => {
        factory({ provide: { assignedPolicyProject: existingAssignedPolicyProject } });
        findScanExecutionPolicyEditor().vm.$emit('save', {
          action,
          policy: mockDastScanExecutionManifest,
        });
        await waitForPromises();
        expect(goToPolicyMR).toHaveBeenCalledTimes(1);
        expect(goToPolicyMR).toHaveBeenCalledWith({
          action,
          assignedPolicyProject: existingAssignedPolicyProject,
          name: mockDastScanExecutionObject.name,
          namespacePath: defaultProjectPath,
          yamlEditorValue: mockDastScanExecutionManifest,
        });
      });
    });

    describe('error handling', () => {
      const createError = (cause) => ({ message: 'There was an error', cause });
      const approverCause = { field: 'approvers_ids' };
      const branchesCause = { field: 'branches' };
      const unknownCause = { field: 'unknown' };

      it('passes down an error with the cause of `approvers_ids` and does not display an error', async () => {
        const error = createError([approverCause]);
        goToPolicyMR.mockRejectedValue(error);
        factory({ provide: { assignedPolicyProject: existingAssignedPolicyProject } });
        await findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
          isActiveRuleMode: true,
        });
        await waitForPromises();
        await nextTick();
        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([
          ['action', '0', 'approvers_ids', [approverCause]],
        ]);
        expect(findErrorAlert().exists()).toBe(false);
      });

      it('passes errors with the cause of `branches` and displays an error', async () => {
        const branchesError = {
          message:
            "Invalid policy YAML\n property '/approval_policy/5/rules/0/branches' is missing required keys: branches ",
          cause: { field: 'branches' },
        };
        goToPolicyMR.mockRejectedValue(branchesError);
        factory({ provide: { assignedPolicyProject: existingAssignedPolicyProject } });
        await findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
        });
        await waitForPromises();
        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([
          ['rules', '0', 'branches'],
        ]);
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe('Invalid policy YAML');
        expect(alert.text()).toBe(
          "property '/approval_policy/5/rules/0/branches' is missing required keys: branches",
        );
      });

      it('does not pass down an error with an unknown cause and displays an error', async () => {
        goToPolicyMR.mockRejectedValue(createError([unknownCause]));
        factory({ provide: { assignedPolicyProject: existingAssignedPolicyProject } });
        await findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
        });
        await waitForPromises();
        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([]);
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe('There was an error');
        expect(alert.text()).toBe('');
      });

      it('handles mixed errors', async () => {
        const error = createError([approverCause, branchesCause, unknownCause]);
        goToPolicyMR.mockRejectedValue(error);
        factory({ provide: { assignedPolicyProject: existingAssignedPolicyProject } });
        await findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
          isActiveRuleMode: true,
        });
        await waitForPromises();
        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([
          ['action', '0', 'approvers_ids', [approverCause]],
        ]);
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe('There was an error');
        expect(alert.text()).toBe('');
      });
    });
  });
});
