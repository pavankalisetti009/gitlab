import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
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
import { mockDastScanExecutionObject } from '../../mocks/mock_scan_execution_policy_data';

Vue.use(VueApollo);

describe('EditorWrapper component', () => {
  let wrapper;
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

  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findPipelineExecutionPolicyEditor = () =>
    wrapper.findComponent(PipelineExecutionPolicyEditor);
  const findScanExecutionPolicyEditor = () => wrapper.findComponent(ScanExecutionPolicyEditor);
  const findScanResultPolicyEditor = () => wrapper.findComponent(ScanResultPolicyEditor);
  const findVulnerabilityManagementPolicyEditor = () =>
    wrapper.findComponent(VulnerabilityManagementPolicyEditor);

  const factory = ({ provide = {}, propsData = {} } = {}) => {
    wrapper = shallowMountExtended(EditorWrapper, {
      propsData: {
        selectedPolicyType: 'container',
        ...propsData,
      },
      provide: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        policyType: undefined,
        ...provide,
      },
      apolloProvider: createMockApollo([
        [getSecurityPolicyProjectSub, getSecurityPolicyProjectSubscriptionHandlerMock],
      ]),
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
    it('subscribes to the newlyCreatedPolicyProject subscription', () => {
      factory({ provide: { namespacePath: 'path/to/namespace' } });
      expect(getSecurityPolicyProjectSubscriptionHandlerMock).not.toHaveBeenCalled();
      // TODO uncomment with feature flag
      // expect(getSecurityPolicyProjectSubscriptionHandlerMock).toHaveBeenCalledWith({
      //   fullPath: 'path/to/namespace',
      // });
    });

    it('updates the project when the subscription fullfills with a project', () => {
      factory({ provide: { namespacePath: 'path/to/namespace' } });
      expect(getSecurityPolicyProjectSubscriptionHandlerMock).not.toHaveBeenCalled();
      // TODO uncomment with feature flag
      // await waitForPromises();
      // expect(findScanExecutionPolicyEditor().props('assignedPolicyProject')).toEqual({
      //   name: 'New project',
      //   fullPath: 'path/to/new-project',
      //   id: '01',
      //   branch: 'main',
      // });
    });
  });
});
