import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import EditorComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/editor_component.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/rule_section.vue';
import ActionBuilder from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_action.vue';
import OverloadWarningModal from 'ee/security_orchestration/components/overload_warning_modal.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import getGroupProjectsCount from 'ee/security_orchestration/graphql/queries/get_group_project_count.query.graphql';
import {
  SCAN_EXECUTION_DEFAULT_POLICY_WITH_SCOPE,
  SCAN_EXECUTION_DEFAULT_POLICY,
  ASSIGNED_POLICY_PROJECT,
  NEW_POLICY_PROJECT,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
  buildScannerAction,
  buildDefaultScheduleRule,
  fromYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import {
  mockDastScanExecutionManifest,
  mockDastScanExecutionObject,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';

import { goToPolicyMR } from 'ee/security_orchestration/components/policy_editor/utils';
import { SECURITY_POLICY_ACTIONS } from 'ee/security_orchestration/components/policy_editor/constants';
import {
  DEFAULT_SCANNER,
  SCAN_EXECUTION_PIPELINE_RULE,
  POLICY_ACTION_BUILDER_TAGS_ERROR_KEY,
  POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY,
  RUNNER_TAGS_PARSING_ERROR,
  DAST_SCANNERS_PARSING_ERROR,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { RULE_KEY_MAP } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/rules';
import { goToYamlMode } from '../policy_editor_helper';

jest.mock('lodash/uniqueId');

jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  assignSecurityPolicyProject: jest.fn().mockResolvedValue({
    branch: 'main',
    fullPath: 'path/to/new-project',
  }),
  goToPolicyMR: jest.fn().mockResolvedValue(),
}));

describe('EditorComponent', () => {
  let wrapper;
  const defaultProjectPath = 'path/to/project';
  const policyEditorEmptyStateSvgPath = 'path/to/svg';
  const scanPolicyDocumentationPath = 'path/to/docs';

  const mockCountResponse = (count = 0) =>
    jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '1',
          projects: {
            count,
          },
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);

    return createMockApollo([[getGroupProjectsCount, handler]]);
  };

  const factory = ({ propsData = {}, provide = {}, handler = mockCountResponse() } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        errorSources: [],
        isCreating: false,
        isDeleting: false,
        isEditing: false,
        ...propsData,
      },
      provide: {
        disableScanPolicyUpdate: false,
        policyEditorEmptyStateSvgPath,
        namespacePath: defaultProjectPath,
        namespaceType: NAMESPACE_TYPES.GROUP,
        scanPolicyDocumentationPath,
        ...provide,
      },
    });
  };

  const factoryWithExistingPolicy = ({ policy = {}, provide = {} } = {}) => {
    return factory({
      propsData: {
        assignedPolicyProject: ASSIGNED_POLICY_PROJECT,
        existingPolicy: { ...mockDastScanExecutionObject, ...policy },
        isEditing: true,
      },
      provide,
    });
  };

  const findAddActionButton = () => wrapper.findByTestId('add-action');
  const findAddRuleButton = () => wrapper.findByTestId('add-rule');
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findActionBuilder = () => wrapper.findComponent(ActionBuilder);
  const findAllActionBuilders = () => wrapper.findAllComponents(ActionBuilder);
  const findRuleSection = () => wrapper.findComponent(RuleSection);
  const findAllRuleSections = () => wrapper.findAllComponents(RuleSection);
  const findOverloadWarningModal = () => wrapper.findComponent(OverloadWarningModal);

  const selectScheduleRule = async () => {
    await findRuleSection().vm.$emit('changed', buildDefaultScheduleRule());
  };

  beforeEach(() => {
    uniqueId.mockImplementation(jest.fn((prefix) => `${prefix}0`));
  });

  describe('default', () => {
    beforeEach(() => {
      factory();
    });
    describe('policy scope', () => {
      it.each`
        namespaceType              | manifest
        ${NAMESPACE_TYPES.GROUP}   | ${SCAN_EXECUTION_DEFAULT_POLICY_WITH_SCOPE}
        ${NAMESPACE_TYPES.PROJECT} | ${SCAN_EXECUTION_DEFAULT_POLICY}
      `('should render default policy for a $namespaceType', ({ namespaceType, manifest }) => {
        factory({ provide: { namespaceType } });
        expect(findPolicyEditorLayout().props('policy')).toEqual(manifest);
      });
    });

    it('should render correctly', () => {
      expect(findPolicyEditorLayout().props()).toMatchObject({
        hasParsingError: false,
        parsingError: '',
      });
    });
  });

  describe('modifying a policy w/ securityPoliciesProjectBackgroundWorker true', () => {
    it.each`
      status                           | action                             | event              | factoryFn                    | yamlEditorValue
      ${'creating a new policy'}       | ${SECURITY_POLICY_ACTIONS.APPEND}  | ${'save-policy'}   | ${factory}                   | ${DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE}
      ${'updating an existing policy'} | ${SECURITY_POLICY_ACTIONS.REPLACE} | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockDastScanExecutionManifest}
      ${'deleting an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE}  | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockDastScanExecutionManifest}
    `('emits "save" when $status', async ({ action, event, factoryFn, yamlEditorValue }) => {
      factoryFn({ provide: { glFeatures: { securityPoliciesProjectBackgroundWorker: true } } });
      findPolicyEditorLayout().vm.$emit(event);
      await waitForPromises();
      expect(wrapper.emitted('save')).toEqual([[{ action, policy: yamlEditorValue }]]);
    });
  });

  describe('saving a policy w/ securityPoliciesProjectBackgroundWorker false', () => {
    it.each`
      status                            | action                             | event              | factoryFn                    | yamlEditorValue                             | currentlyAssignedPolicyProject
      ${'to save a new policy'}         | ${SECURITY_POLICY_ACTIONS.APPEND}  | ${'save-policy'}   | ${factory}                   | ${DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE} | ${NEW_POLICY_PROJECT}
      ${'to update an existing policy'} | ${SECURITY_POLICY_ACTIONS.REPLACE} | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockDastScanExecutionManifest}            | ${ASSIGNED_POLICY_PROJECT}
      ${'to delete an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE}  | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockDastScanExecutionManifest}            | ${ASSIGNED_POLICY_PROJECT}
    `(
      'navigates to the new merge request when "goToPolicyMR" is emitted $status',
      async ({ action, event, factoryFn, yamlEditorValue, currentlyAssignedPolicyProject }) => {
        factoryFn();
        findPolicyEditorLayout().vm.$emit(event);
        await waitForPromises();
        expect(goToPolicyMR).toHaveBeenCalledTimes(1);
        expect(goToPolicyMR).toHaveBeenCalledWith({
          action,
          assignedPolicyProject: currentlyAssignedPolicyProject,
          name:
            action === SECURITY_POLICY_ACTIONS.APPEND
              ? fromYaml({ manifest: yamlEditorValue }).name
              : mockDastScanExecutionObject.name,
          namespacePath: defaultProjectPath,
          yamlEditorValue,
        });
      },
    );

    describe('error handling', () => {
      const createError = (cause) => ({ message: 'There was an error', cause });
      const approverCause = { field: 'approvers_ids' };
      const branchesCause = { field: 'branches' };
      const unknownCause = { field: 'unknown' };

      describe('when in rule mode', () => {
        it('passes errors with the cause of `approvers_ids` to the action section', async () => {
          const error = createError([approverCause]);
          goToPolicyMR.mockRejectedValue(error);
          factoryWithExistingPolicy();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });

        it('emits error with the cause of `branches`', async () => {
          const error = createError([branchesCause]);
          goToPolicyMR.mockRejectedValue(error);
          factoryWithExistingPolicy();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });

        it('emits error with an unknown cause', async () => {
          const error = createError([unknownCause]);
          goToPolicyMR.mockRejectedValue(error);
          factoryWithExistingPolicy();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });

        it('handles mixed errors', async () => {
          const error = createError([approverCause, branchesCause, unknownCause]);
          goToPolicyMR.mockRejectedValue(error);
          factoryWithExistingPolicy();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(wrapper.emitted('error')).toStrictEqual([[''], ['There was an error']]);
        });
      });

      describe('when in yaml mode', () => {
        it('emits errors', async () => {
          const error = createError([approverCause, branchesCause, unknownCause]);
          goToPolicyMR.mockRejectedValue(error);
          factoryWithExistingPolicy();
          goToYamlMode(findPolicyEditorLayout);
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });
      });
    });
  });

  describe('when a user is not an owner of the project', () => {
    it('displays the empty state with the appropriate properties', async () => {
      factory({ provide: { disableScanPolicyUpdate: true } });
      await nextTick();
      const emptyState = findEmptyState();

      expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
      expect(emptyState.props('primaryButtonLink')).toMatch('scan-execution-policy-editor');
      expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
    });
  });

  describe('modifying a policy', () => {
    beforeEach(factory);

    it('updates the yaml and policy object when "update-yaml" is emitted', async () => {
      const newManifest = `name: test
enabled: true`;

      expect(findPolicyEditorLayout().props()).toMatchObject({
        hasParsingError: false,
        parsingError: '',
        policy: fromYaml({ manifest: DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE }),
        yamlEditorValue: DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
      });
      findPolicyEditorLayout().vm.$emit('update-yaml', newManifest);
      await nextTick();
      expect(findPolicyEditorLayout().props()).toMatchObject({
        hasParsingError: false,
        parsingError: '',
        policy: expect.objectContaining({ enabled: true }),
        yamlEditorValue: newManifest,
      });
    });

    describe('properties', () => {
      it.each`
        component        | oldValue | newValue
        ${'name'}        | ${''}    | ${'new policy name'}
        ${'description'} | ${''}    | ${'new description'}
        ${'enabled'}     | ${true}  | ${false}
      `('updates the $component property', async ({ component, newValue, oldValue }) => {
        expect(findPolicyEditorLayout().props('policy')[component]).toBe(oldValue);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toMatch(
          `${component}: ${oldValue}`,
        );

        findPolicyEditorLayout().vm.$emit('update-property', component, newValue);
        await nextTick();

        expect(findPolicyEditorLayout().props('policy')[component]).toBe(newValue);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toMatch(
          `${component}: ${newValue}`,
        );
      });

      it('removes the policy scope property', async () => {
        const oldValue = {
          policy_scope: { compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }] },
        };

        factoryWithExistingPolicy({ policy: oldValue });
        expect(findPolicyEditorLayout().props('policy').policy_scope).toEqual(
          oldValue.policy_scope,
        );
        await findPolicyEditorLayout().vm.$emit('remove-property', 'policy_scope');
        expect(findPolicyEditorLayout().props('policy').policy_scope).toBe(undefined);
      });
    });
  });

  describe('policy rule builder', () => {
    beforeEach(() => {
      uniqueId.mockRestore();
      factory();
    });

    it('should add new rule', async () => {
      const initialValue = [RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE]()];
      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(initialValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toStrictEqual(initialValue);
      expect(findAllRuleSections()).toHaveLength(1);

      findAddRuleButton().vm.$emit('click');
      await nextTick();

      const finalValue = [
        RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE](),
        RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE](),
      ];
      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(finalValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toStrictEqual(finalValue);
      expect(findAllRuleSections()).toHaveLength(2);
    });

    it('should update rule', async () => {
      const initialValue = [RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE]()];
      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(initialValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toStrictEqual(initialValue);

      const finalValue = [{ ...RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE](), branches: ['main'] }];
      findRuleSection().vm.$emit('changed', finalValue[0]);
      await nextTick();

      expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(finalValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toStrictEqual(finalValue);
    });

    it('should remove rule', async () => {
      findAddRuleButton().vm.$emit('click');
      await nextTick();

      expect(findAllRuleSections()).toHaveLength(2);
      expect(findPolicyEditorLayout().props('policy').rules).toHaveLength(2);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toHaveLength(2);

      findRuleSection().vm.$emit('remove', 1);
      await nextTick();

      expect(findAllRuleSections()).toHaveLength(1);
      expect(findPolicyEditorLayout().props('policy').rules).toHaveLength(1);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).rules,
      ).toHaveLength(1);
    });
  });

  describe('policy action builder', () => {
    beforeEach(() => {
      uniqueId.mockRestore();
      factory();
    });

    it('should add new action', async () => {
      const initialValue = [buildScannerAction({ scanner: DEFAULT_SCANNER })];
      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(initialValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toStrictEqual(initialValue);

      findAddActionButton().vm.$emit('click');
      await nextTick();

      const finalValue = [
        buildScannerAction({ scanner: DEFAULT_SCANNER }),
        buildScannerAction({ scanner: DEFAULT_SCANNER }),
      ];
      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(finalValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toStrictEqual(finalValue);
    });

    it('should update action', async () => {
      const initialValue = [buildScannerAction({ scanner: DEFAULT_SCANNER })];
      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(initialValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toStrictEqual(initialValue);

      const finalValue = [buildScannerAction({ scanner: 'sast' })];
      findActionBuilder().vm.$emit('changed', finalValue[0]);
      await nextTick();

      expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(finalValue);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toStrictEqual(finalValue);
    });

    it('should remove action', async () => {
      findAddActionButton().vm.$emit('click');
      await nextTick();

      expect(findAllActionBuilders()).toHaveLength(2);
      expect(findPolicyEditorLayout().props('policy').actions).toHaveLength(2);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toHaveLength(2);

      findActionBuilder().vm.$emit('remove', 1);
      await nextTick();

      expect(findAllActionBuilders()).toHaveLength(1);
      expect(findPolicyEditorLayout().props('policy').actions).toHaveLength(1);
      expect(
        fromYaml({ manifest: findPolicyEditorLayout().props('yamlEditorValue') }).actions,
      ).toHaveLength(1);
    });
  });

  describe('parsing tags errors', () => {
    beforeEach(() => {
      factory();
    });

    it.each`
      name               | errorKey                                         | expectedErrorMessage
      ${'tags'}          | ${POLICY_ACTION_BUILDER_TAGS_ERROR_KEY}          | ${RUNNER_TAGS_PARSING_ERROR}
      ${'DAST profiles'} | ${POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY} | ${DAST_SCANNERS_PARSING_ERROR}
    `(
      'disables rule editor when parsing of $name fails',
      async ({ errorKey, expectedErrorMessage }) => {
        findActionBuilder().vm.$emit('parsing-error', errorKey);
        await nextTick();
        expect(findPolicyEditorLayout().props('hasParsingError')).toBe(true);
        expect(findPolicyEditorLayout().props('parsingError')).toBe(expectedErrorMessage);
      },
    );
  });

  describe('performance warning modal', () => {
    describe('group', () => {
      describe('performance threshold not reached', () => {
        beforeEach(() => {
          factory();
        });

        it('saves policy when performance threshold is not reached', async () => {
          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(goToPolicyMR).toHaveBeenCalled();
        });

        it('saves policy when performance threshold is not reached and schedule rule is selected', async () => {
          await selectScheduleRule();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(goToPolicyMR).toHaveBeenCalled();
        });
      });

      it('does not show the warning when performance threshold is reached but no schedule rules were selected', async () => {
        factory({
          handler: mockCountResponse(1001),
        });
        await waitForPromises();

        findPolicyEditorLayout().vm.$emit('save-policy');
        await waitForPromises();

        expect(findOverloadWarningModal().props('visible')).toBe(false);
        expect(goToPolicyMR).toHaveBeenCalled();
      });

      describe('performance threshold reached', () => {
        beforeEach(async () => {
          factory({
            handler: mockCountResponse(1001),
          });

          await waitForPromises();
        });

        it('shows the warning when performance threshold is reached but schedule rules were selected', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(goToPolicyMR).toHaveBeenCalledTimes(0);
        });

        it('dismisses the warning without saving the policy', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(goToPolicyMR).toHaveBeenCalledTimes(0);

          await findOverloadWarningModal().vm.$emit('cancel-submit');

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(goToPolicyMR).toHaveBeenCalledTimes(0);
        });

        it('dismisses the warning and save the policy', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(goToPolicyMR).toHaveBeenCalledTimes(0);

          await findOverloadWarningModal().vm.$emit('confirm-submit');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(goToPolicyMR).toHaveBeenCalledTimes(1);
        });

        it('also shows warning modal in yaml mode', async () => {
          await selectScheduleRule();
          await waitForPromises();

          goToYamlMode(findPolicyEditorLayout);
          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(goToPolicyMR).toHaveBeenCalledTimes(0);
        });
      });
    });

    describe('project', () => {
      beforeEach(async () => {
        factory({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
          },
          handler: mockCountResponse(1001),
        });

        await waitForPromises();
      });

      it('does not show the warning when performance threshold is reached but schedule rules were selected for a project', async () => {
        await selectScheduleRule();
        await waitForPromises();

        findPolicyEditorLayout().vm.$emit('save-policy');
        await waitForPromises();

        expect(findOverloadWarningModal().props('visible')).toBe(false);
        expect(goToPolicyMR).toHaveBeenCalledTimes(1);
      });
    });
  });
});
