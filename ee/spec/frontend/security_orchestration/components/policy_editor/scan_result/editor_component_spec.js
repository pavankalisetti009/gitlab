import { GlEmptyState } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_section.vue';
import FallbackSection from 'ee/security_orchestration/components/policy_editor/scan_result/fallback_section.vue';
import {
  CLOSED,
  OPEN,
} from 'ee/security_orchestration/components/policy_editor/scan_result/constants';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import {
  ACTION_LISTBOX_ITEMS,
  BOT_MESSAGE_TYPE,
  buildApprovalAction,
  buildBotMessageAction,
  DISABLED_BOT_MESSAGE_ACTION,
  SCAN_FINDING,
  DEFAULT_SCAN_RESULT_POLICY,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE,
  getInvalidBranches,
  fromYaml,
  REQUIRE_APPROVAL_TYPE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import EditorComponent from 'ee/security_orchestration/components/policy_editor/scan_result/editor_component.vue';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
  USER_TYPE,
} from 'ee/security_orchestration/constants';
import {
  mockDefaultBranchesScanResultManifest,
  mockDefaultBranchesScanResultObject,
  mockDeprecatedScanResultManifest,
  mockDeprecatedScanResultObject,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import {
  unsupportedManifest,
  APPROVAL_POLICY_DEFAULT_POLICY,
  APPROVAL_POLICY_DEFAULT_POLICY_WITH_SCOPE,
  ASSIGNED_POLICY_PROJECT,
  NEW_POLICY_PROJECT,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  buildSettingsList,
  PERMITTED_INVALID_SETTINGS,
  BLOCK_BRANCH_MODIFICATION,
  PREVENT_PUSHING_AND_FORCE_PUSHING,
  PREVENT_APPROVAL_BY_AUTHOR,
  PREVENT_APPROVAL_BY_COMMIT_AUTHOR,
  REMOVE_APPROVALS_WITH_NEW_COMMIT,
  REQUIRE_PASSWORD_TO_APPROVE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';

import {
  goToPolicyMR,
  removeIdsFromPolicy,
} from 'ee/security_orchestration/components/policy_editor/utils';
import {
  SECURITY_POLICY_ACTIONS,
  PARSING_ERROR_MESSAGE,
} from 'ee/security_orchestration/components/policy_editor/constants';
import DimDisableContainer from 'ee/security_orchestration/components/policy_editor/dim_disable_container.vue';
import ActionSection from 'ee/security_orchestration/components/policy_editor/scan_result/action/action_section.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/rule_section.vue';
import { goToRuleMode, goToYamlMode } from '../policy_editor_helper';

jest.mock('lodash/uniqueId');

jest.mock('ee/security_orchestration/components/policy_editor/scan_result/lib', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/scan_result/lib'),
  getInvalidBranches: jest.fn().mockResolvedValue([]),
}));

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
  const scanResultPolicyApprovers = {
    user: [{ id: 1, username: 'the.one', state: 'active' }],
    group: [],
    role: [],
  };

  const factory = ({ propsData = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        isEditing: false,
        ...propsData,
      },
      provide: {
        disableScanPolicyUpdate: false,
        policyEditorEmptyStateSvgPath,
        namespaceId: 1,
        namespacePath: defaultProjectPath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        scanPolicyDocumentationPath,
        scanResultPolicyApprovers,
        glFeatures,
        ...provide,
      },
    });
  };

  const factoryWithExistingPolicy = ({
    policy = {},
    provide = {},
    hasActions = true,
    glFeatures = {},
  } = {}) => {
    const existingPolicy = { ...mockDefaultBranchesScanResultObject };

    if (!hasActions) {
      delete existingPolicy.actions;
    }

    return factory({
      propsData: {
        assignedPolicyProject: ASSIGNED_POLICY_PROJECT,
        existingPolicy: { ...existingPolicy, ...policy },
        isEditing: true,
      },
      provide,
      glFeatures,
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findFallbackSection = () => wrapper.findComponent(FallbackSection);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findActionSection = () => wrapper.findComponent(ActionSection);
  const findAllActionSections = () => wrapper.findAllComponents(ActionSection);
  const findAddRuleButton = () => wrapper.findByTestId('add-rule');
  const findAllDisabledComponents = () => wrapper.findAllComponents(DimDisableContainer);
  const findAllRuleSections = () => wrapper.findAllComponents(RuleSection);
  const findSettingsSection = () => wrapper.findComponent(SettingsSection);
  const findEmptyActionsAlert = () => wrapper.findByTestId('empty-actions-alert');
  const findScanFilterSelector = () => wrapper.findComponent(ScanFilterSelector);

  const verifiesParsingError = () => {
    expect(findPolicyEditorLayout().props('hasParsingError')).toBe(true);
    expect(findPolicyEditorLayout().attributes('parsingerror')).toBe(PARSING_ERROR_MESSAGE);
  };

  beforeEach(() => {
    getInvalidBranches.mockClear();
    uniqueId
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}0`))
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}1`))
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}2`));
  });

  afterEach(() => {
    uniqueId.mockRestore();
  });

  describe('rendering', () => {
    it.each`
      namespaceType              | policy
      ${NAMESPACE_TYPES.GROUP}   | ${APPROVAL_POLICY_DEFAULT_POLICY_WITH_SCOPE}
      ${NAMESPACE_TYPES.PROJECT} | ${APPROVAL_POLICY_DEFAULT_POLICY}
    `('should render default policy for a $namespaceType', ({ namespaceType, policy }) => {
      factory({ provide: { namespaceType } });
      expect(findPolicyEditorLayout().props('policy')).toStrictEqual(policy);
      expect(findPolicyEditorLayout().props('hasParsingError')).toBe(false);
    });

    it.each`
      namespaceType              | manifest
      ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE}
      ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_RESULT_POLICY}
    `(
      'should use the correct default policy yaml for a $namespaceType',
      ({ namespaceType, manifest }) => {
        factory({ provide: { namespaceType } });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(manifest);
      },
    );

    it('displays the initial rule and add rule button', () => {
      factory();
      expect(findAllRuleSections()).toHaveLength(1);
      expect(findAddRuleButton().exists()).toBe(true);
    });

    describe('when a user is not an owner of the project', () => {
      it('displays the empty state with the appropriate properties', () => {
        factory({ provide: { disableScanPolicyUpdate: true } });

        const emptyState = findEmptyState();

        expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
        expect(emptyState.props('primaryButtonLink')).toMatch('scan-result-policy-editor');
        expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
      });
    });

    describe('existing policy', () => {
      it('displays an approval policy', () => {
        factoryWithExistingPolicy();
        expect(findEmptyActionsAlert().exists()).toBe(false);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
          mockDefaultBranchesScanResultManifest,
        );
        expect(findAllRuleSections()).toHaveLength(1);
        expect(findAllActionSections()).toHaveLength(2);
      });

      it('displays a scan result policy', () => {
        factoryWithExistingPolicy({ policy: mockDeprecatedScanResultObject });
        expect(findPolicyEditorLayout().props('hasParsingError')).toBe(false);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
          mockDeprecatedScanResultManifest,
        );
        expect(findAllRuleSections()).toHaveLength(1);
        expect(findAllActionSections()).toHaveLength(2);
      });
    });
  });

  describe('rule mode updates', () => {
    describe('properties', () => {
      it.each`
        component         | oldValue     | newValue
        ${'name'}         | ${''}        | ${'new policy name'}
        ${'description'}  | ${''}        | ${'new description'}
        ${'enabled'}      | ${true}      | ${false}
        ${'policy_scope'} | ${undefined} | ${{ compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }] }}
      `('updates the $component property', ({ component, newValue, oldValue }) => {
        factory();
        expect(findPolicyEditorLayout().props('policy')[component]).toEqual(oldValue);
        findPolicyEditorLayout().vm.$emit('update-property', component, newValue);
        expect(findPolicyEditorLayout().props('policy')[component]).toEqual(newValue);
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

    describe('rule section', () => {
      it('adds a new rule', async () => {
        const rulesCount = 1;
        factory();
        expect(findAllRuleSections()).toHaveLength(rulesCount);
        await findAddRuleButton().vm.$emit('click');
        expect(findAllRuleSections()).toHaveLength(rulesCount + 1);
      });

      it('hides add button when the limit of five rules has been reached', () => {
        const limit = 5;
        const { id, ...rule } = mockDefaultBranchesScanResultObject.rules[0];
        uniqueId.mockRestore();
        factoryWithExistingPolicy({ policy: { rules: [rule, rule, rule, rule, rule] } });
        expect(findAllRuleSections()).toHaveLength(limit);
        expect(findAddRuleButton().exists()).toBe(false);
      });

      it('updates an existing rule', async () => {
        const newValue = {
          type: 'scan_finding',
          branches: [],
          scanners: [],
          vulnerabilities_allowed: 1,
          severity_levels: [],
          vulnerability_states: [],
        };
        factory();

        await findAllRuleSections().at(0).vm.$emit('changed', newValue);
        expect(findAllRuleSections().at(0).props('initRule')).toEqual(newValue);
        expect(findPolicyEditorLayout().props('policy').rules[0].vulnerabilities_allowed).toBe(1);
      });

      it('deletes the initial rule', async () => {
        const initialRuleCount = 1;
        factory();

        expect(findAllRuleSections()).toHaveLength(initialRuleCount);

        await findAllRuleSections().at(0).vm.$emit('remove', 0);

        expect(findAllRuleSections()).toHaveLength(initialRuleCount - 1);
      });
    });

    describe('action section', () => {
      describe('rendering', () => {
        describe.each`
          namespaceType              | manifest
          ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE}
          ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_RESULT_POLICY}
        `('$namespaceType', ({ namespaceType, manifest }) => {
          it('should use the correct default policy yaml for a $namespaceType', () => {
            factory({ provide: { namespaceType } });
            expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(manifest);
          });

          it('displays the approver action and the add action button on the group-level', () => {
            factory({ provide: { namespaceType } });
            expect(findActionSection().exists()).toBe(true);
            expect(findAllActionSections()).toHaveLength(2);
          });
        });

        describe('bot message action section', () => {
          it('does not display a bot message action section if there is a bot message action in the policy with `enabled: false`', () => {
            factoryWithExistingPolicy({
              policy: {
                ...mockDefaultBranchesScanResultObject,
                actions: [DISABLED_BOT_MESSAGE_ACTION],
              },
            });
            expect(findAllActionSections()).toHaveLength(0);
            expect(findScanFilterSelector().props('filters')).toEqual(ACTION_LISTBOX_ITEMS);
          });

          it('displays a bot message action section if there is no bot message action in the policy', () => {
            factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });
            const actionSections = findAllActionSections();
            expect(actionSections).toHaveLength(2);
            expect(actionSections.at(1).props('initAction')).toEqual(
              expect.objectContaining({ type: BOT_MESSAGE_TYPE, enabled: true }),
            );
          });
        });
      });

      describe('add', () => {
        it('hides the scan filter selector by default, when all action types are used', () => {
          factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });
          expect(findScanFilterSelector().exists()).toBe(false);
        });

        it('shows the scan filter selector if there are action types not shown', async () => {
          factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });
          await findAllActionSections().at(0).vm.$emit('remove');
          expect(findScanFilterSelector().exists()).toBe(true);
          expect(findScanFilterSelector().props('filters')).toEqual([
            { text: 'Require Approvers', value: REQUIRE_APPROVAL_TYPE },
          ]);
        });

        it('updates an existing bot message action to be `enabled: true` when a bot message action is added', async () => {
          factoryWithExistingPolicy({
            policy: {
              ...mockDefaultBranchesScanResultObject,
              actions: [DISABLED_BOT_MESSAGE_ACTION],
            },
          });
          const { id: disabledId, ...disabledAction } = DISABLED_BOT_MESSAGE_ACTION;
          expect(findPolicyEditorLayout().props('policy').actions).toEqual([
            expect.objectContaining(disabledAction),
          ]);
          await findScanFilterSelector().vm.$emit('select', BOT_MESSAGE_TYPE);
          expect(findAllActionSections()).toHaveLength(1);
          const { id, ...action } = buildBotMessageAction();
          expect(findPolicyEditorLayout().props('policy').actions).toEqual([
            expect.objectContaining(action),
          ]);
        });
      });

      describe('remove', () => {
        it('removes the approver action', async () => {
          factory();
          expect(findAllActionSections()).toHaveLength(2);
          await findActionSection().vm.$emit('remove');
          expect(findAllActionSections()).toHaveLength(1);
          expect(findPolicyEditorLayout().props('policy').actions).not.toContainEqual(
            buildApprovalAction(),
          );
        });

        it('disables the bot message action', async () => {
          factory();
          expect(findAllActionSections()).toHaveLength(2);
          await findActionSection().vm.$emit('changed', DISABLED_BOT_MESSAGE_ACTION);
          expect(findAllActionSections()).toHaveLength(1);
          expect(findPolicyEditorLayout().props('policy').actions).toContainEqual(
            DISABLED_BOT_MESSAGE_ACTION,
          );
        });

        it('removes the action approvers when the action is removed', async () => {
          factory();
          await findActionSection().vm.$emit(
            'changed',
            mockDefaultBranchesScanResultObject.actions[0],
          );
          await findAllActionSections().at(0).vm.$emit('remove');
          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(removeIdsFromPolicy(findPolicyEditorLayout().props('policy')).actions).toEqual([
            { type: BOT_MESSAGE_TYPE, enabled: true },
            { approvals_required: 1, type: REQUIRE_APPROVAL_TYPE },
          ]);
          expect(findActionSection().props('existingApprovers')).toEqual({});
        });
      });

      describe('update', () => {
        beforeEach(() => {
          factory();
        });

        it('updates policy action when edited', async () => {
          const UPDATED_ACTION = {
            approvals_required: 1,
            group_approvers_ids: [29],
            id: 'action_0',
            type: REQUIRE_APPROVAL_TYPE,
          };
          await findActionSection().vm.$emit('changed', UPDATED_ACTION);
          expect(findActionSection().props('initAction')).toEqual(UPDATED_ACTION);
        });

        it('updates the policy approvers', async () => {
          const newApprover = ['owner'];

          await findActionSection().vm.$emit('updateApprovers', {
            ...scanResultPolicyApprovers,
            role: newApprover,
          });

          expect(findActionSection().props('existingApprovers')).toMatchObject({
            role: newApprover,
          });
        });

        it('creates an error when the action section emits one', async () => {
          await findActionSection().vm.$emit('error');
          verifiesParsingError();
        });
      });
    });
  });

  describe('yaml mode updates', () => {
    beforeEach(factory);

    it('updates the policy yaml and policy object when "update-yaml" is emitted', async () => {
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockDefaultBranchesScanResultManifest);
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
        mockDefaultBranchesScanResultManifest,
      );
      expect(removeIdsFromPolicy(findPolicyEditorLayout().props('policy'))).toMatchObject(
        removeIdsFromPolicy(mockDefaultBranchesScanResultObject),
      );
    });

    it('disables all rule mode related components when the yaml is invalid', async () => {
      await findPolicyEditorLayout().vm.$emit('update-yaml', unsupportedManifest);

      expect(findAllDisabledComponents().at(0).props('disabled')).toBe(true);
      expect(findAllDisabledComponents().at(1).props('disabled')).toBe(true);
    });
  });

  describe('CRUD operations', () => {
    it.each`
      status                            | action                             | event              | factoryFn                    | yamlEditorValue                          | currentlyAssignedPolicyProject
      ${'to save a new policy'}         | ${SECURITY_POLICY_ACTIONS.APPEND}  | ${'save-policy'}   | ${factory}                   | ${DEFAULT_SCAN_RESULT_POLICY}            | ${NEW_POLICY_PROJECT}
      ${'to update an existing policy'} | ${SECURITY_POLICY_ACTIONS.REPLACE} | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockDefaultBranchesScanResultManifest} | ${ASSIGNED_POLICY_PROJECT}
      ${'to delete an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE}  | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockDefaultBranchesScanResultManifest} | ${ASSIGNED_POLICY_PROJECT}
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
              : mockDefaultBranchesScanResultObject.name,
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
          factory();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findActionSection().props('errors')).toEqual(error.cause);
          expect(wrapper.emitted('error')).toStrictEqual([['']]);
        });

        it('emits error with the cause of `branches`', async () => {
          const error = createError([branchesCause]);
          goToPolicyMR.mockRejectedValue(error);
          factory();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findActionSection().props('errors')).toEqual([]);
          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });

        it('emits error with an unknown cause', async () => {
          const error = createError([unknownCause]);
          goToPolicyMR.mockRejectedValue(error);
          factory();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findActionSection().props('errors')).toEqual([]);
          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });

        it('handles mixed errors', async () => {
          const error = createError([approverCause, branchesCause, unknownCause]);
          goToPolicyMR.mockRejectedValue(error);
          factory();
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findActionSection().props('errors')).toEqual([approverCause]);
          expect(wrapper.emitted('error')).toStrictEqual([[''], ['There was an error']]);
        });
      });

      describe('when in yaml mode', () => {
        it('emits errors', async () => {
          const error = createError([approverCause, branchesCause, unknownCause]);
          goToPolicyMR.mockRejectedValue(error);
          factory();
          goToYamlMode(findPolicyEditorLayout);
          await findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findActionSection().props('errors')).toEqual([]);
          expect(wrapper.emitted('error')).toStrictEqual([[''], [error.message]]);
        });
      });
    });
  });

  describe('errors', () => {
    it('creates an error for invalid yaml', async () => {
      factory();

      await findPolicyEditorLayout().vm.$emit('update-yaml', 'invalid manifest');

      verifiesParsingError();
    });

    it('creates an error when policy scanners are invalid', async () => {
      factoryWithExistingPolicy({ policy: { rules: [{ scanners: ['cluster_image_scanning'] }] } });

      await goToRuleMode(findPolicyEditorLayout);
      verifiesParsingError();
    });

    it('creates an error when policy severity_levels are invalid', async () => {
      factoryWithExistingPolicy({ policy: { rules: [{ severity_levels: ['non-existent'] }] } });

      await goToRuleMode(findPolicyEditorLayout);
      verifiesParsingError();
    });

    it('creates an error when vulnerabilities_allowed are invalid', async () => {
      factoryWithExistingPolicy({ policy: { rules: [{ vulnerabilities_allowed: 'invalid' }] } });

      await goToRuleMode(findPolicyEditorLayout);
      verifiesParsingError();
    });

    it('creates an error when vulnerability_states are invalid', async () => {
      factoryWithExistingPolicy({ policy: { rules: [{ vulnerability_states: ['invalid'] }] } });

      await goToRuleMode(findPolicyEditorLayout);
      verifiesParsingError();
    });

    it('creates an error when vulnerability_age is invalid', async () => {
      factoryWithExistingPolicy({
        policy: { rules: [{ vulnerability_age: { operator: 'invalid' } }] },
      });

      await goToRuleMode(findPolicyEditorLayout);
      verifiesParsingError();
    });

    it('creates an error when vulnerability_attributes are invalid', async () => {
      factoryWithExistingPolicy({
        policy: { rules: [{ vulnerability_attributes: [{ invalid: true }] }] },
      });

      await goToRuleMode(findPolicyEditorLayout);
      verifiesParsingError();
    });

    describe('existing approvers', () => {
      const existingPolicyWithUserId = {
        actions: [
          buildBotMessageAction(),
          { type: REQUIRE_APPROVAL_TYPE, approvals_required: 1, user_approvers_ids: [1] },
        ],
      };

      const existingUserApprover = {
        user: [{ id: 1, username: 'the.one', state: 'active', type: USER_TYPE }],
      };
      const nonExistingUserApprover = {
        user: [{ id: 2, username: 'the.two', state: 'active', type: USER_TYPE }],
      };

      it.each`
        title         | policy                      | approver                   | output
        ${'does not'} | ${{}}                       | ${existingUserApprover}    | ${false}
        ${'does'}     | ${{}}                       | ${nonExistingUserApprover} | ${true}
        ${'does not'} | ${existingPolicyWithUserId} | ${existingUserApprover}    | ${false}
        ${'does'}     | ${existingPolicyWithUserId} | ${nonExistingUserApprover} | ${true}
      `(
        '$title create an error when the policy does not match existing approvers',
        async ({ policy, approver, output }) => {
          factoryWithExistingPolicy({
            policy,
            provide: {
              scanResultPolicyApprovers: approver,
            },
          });

          await goToRuleMode(findPolicyEditorLayout);
          expect(findPolicyEditorLayout().props('hasParsingError')).toBe(output);
        },
      );
    });
  });

  describe('branches being validated', () => {
    it.each`
      status                             | value       | errorMessage
      ${'invalid branches do not exist'} | ${[]}       | ${''}
      ${'invalid branches exist'}        | ${['main']} | ${'The following branches do not exist on this development project: main. Please review all protected branches to ensure the values are accurate before updating this policy.'}
    `(
      'triggers error event with the correct content when $status',
      async ({ value, errorMessage }) => {
        const rule = { ...mockDefaultBranchesScanResultObject.rules[0], branches: ['main'] };
        getInvalidBranches.mockReturnValue(value);

        factoryWithExistingPolicy({ policy: { rules: [rule] } });

        await goToRuleMode(findPolicyEditorLayout);
        await waitForPromises();
        const errors = wrapper.emitted('error');

        expect(errors[errors.length - 1]).toEqual([errorMessage]);
      },
    );

    it('does not query protected branches when namespaceType is other than project', async () => {
      factoryWithExistingPolicy({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });

      await goToRuleMode(findPolicyEditorLayout);
      await waitForPromises();

      expect(getInvalidBranches).not.toHaveBeenCalled();
    });
  });

  describe('settings section', () => {
    describe('settings', () => {
      const defaultProjectApprovalConfiguration = {
        [PREVENT_PUSHING_AND_FORCE_PUSHING]: true,
        [BLOCK_BRANCH_MODIFICATION]: true,
        [PREVENT_APPROVAL_BY_AUTHOR]: true,
        [PREVENT_APPROVAL_BY_COMMIT_AUTHOR]: true,
        [REMOVE_APPROVALS_WITH_NEW_COMMIT]: true,
        [REQUIRE_PASSWORD_TO_APPROVE]: false,
      };

      beforeEach(() => {
        factory();
      });

      it('displays setting section', () => {
        expect(findSettingsSection().exists()).toBe(true);
        expect(findSettingsSection().props('settings')).toEqual(
          defaultProjectApprovalConfiguration,
        );
      });

      it('updates the policy when settings change', async () => {
        findAllRuleSections().at(0).vm.$emit('changed', { type: 'any_merge_request' });
        await findSettingsSection().vm.$emit('changed', {
          [PREVENT_APPROVAL_BY_AUTHOR]: false,
        });
        expect(findSettingsSection().props('settings')).toEqual({
          ...buildSettingsList(),
          [PREVENT_APPROVAL_BY_AUTHOR]: false,
        });
      });

      it('updates the policy when a change is emitted for pushingBranchesConfiguration', async () => {
        await findSettingsSection().vm.$emit('changed', {
          [PREVENT_PUSHING_AND_FORCE_PUSHING]: false,
        });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(
          `${PREVENT_PUSHING_AND_FORCE_PUSHING}: false`,
        );
      });

      it('updates the policy when a change is emitted for blockBranchModification', async () => {
        await findSettingsSection().vm.$emit('changed', {
          [BLOCK_BRANCH_MODIFICATION]: false,
        });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(
          `${BLOCK_BRANCH_MODIFICATION}: false`,
        );
      });

      it('updates the settings containing permitted invalid settings', () => {
        factoryWithExistingPolicy({ policy: { approval_settings: PERMITTED_INVALID_SETTINGS } });
        expect(findPolicyEditorLayout().props('policy')).toEqual(
          expect.objectContaining({ approval_settings: PERMITTED_INVALID_SETTINGS }),
        );
        findAllRuleSections().at(0).vm.$emit('changed', { type: SCAN_FINDING });
        expect(findPolicyEditorLayout().props('policy')).toEqual(
          expect.objectContaining({
            approval_settings: buildSettingsList(),
          }),
        );
      });
    });

    describe('empty policy alert', () => {
      const settingsPolicy = { approval_settings: { [BLOCK_BRANCH_MODIFICATION]: true } };
      const disabledBotPolicy = { actions: [{ type: BOT_MESSAGE_TYPE, enabled: false }] };
      const disabledBotPolicyWithSettings = {
        approval_settings: { [BLOCK_BRANCH_MODIFICATION]: true },
        actions: [{ type: BOT_MESSAGE_TYPE, enabled: false }],
      };

      describe.each`
        title                                                       | policy                           | hasActions | hasAlert | alertVariant
        ${'has require approval action and settings'}               | ${settingsPolicy}                | ${true}    | ${false} | ${''}
        ${'has require approval action but does not have settings'} | ${{}}                            | ${true}    | ${false} | ${''}
        ${'has settings but does not have actions'}                 | ${settingsPolicy}                | ${false}   | ${true}  | ${'warning'}
        ${'does not have actions or settings'}                      | ${{}}                            | ${false}   | ${true}  | ${'warning'}
        ${'has disabled bot action and has settings'}               | ${disabledBotPolicyWithSettings} | ${true}    | ${true}  | ${'warning'}
        ${'has disabled bot action but does not have settings'}     | ${disabledBotPolicy}             | ${true}    | ${true}  | ${'danger'}
      `('$title', ({ policy, hasActions, hasAlert, alertVariant }) => {
        beforeEach(() => {
          factoryWithExistingPolicy({ policy, hasActions });
        });

        it('renders the alert appropriately', () => {
          expect(findEmptyActionsAlert().exists()).toBe(hasAlert);
          if (hasAlert) {
            expect(findEmptyActionsAlert().props('variant')).toBe(alertVariant);
          }
        });
      });
    });
  });

  describe('fallback section', () => {
    it('renders the fallback section with "property: closed" for a policy without fallback section', () => {
      factory();
      expect(findFallbackSection().props()).toEqual({
        disabled: false,
        property: CLOSED,
      });
    });

    it('renders the fallback section with the fallback property in the yaml', () => {
      factoryWithExistingPolicy({
        policy: { fallback_behavior: { fail: OPEN } },
      });
      expect(findFallbackSection().props()).toEqual({
        disabled: false,
        property: OPEN,
      });
    });
  });
});
