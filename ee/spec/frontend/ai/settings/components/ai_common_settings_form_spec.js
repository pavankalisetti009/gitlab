import { nextTick } from 'vue';
import { GlForm, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCommonSettingsForm from 'ee/ai/settings/components/ai_common_settings_form.vue';
import DuoAvailabilityForm from 'ee/ai/settings/components/duo_availability_form.vue';
import DuoExperimentBetaFeaturesForm from 'ee/ai/settings/components/duo_experiment_beta_features_form.vue';
import DuoCoreFeaturesForm from 'ee/ai/settings/components/duo_core_features_form.vue';
import DuoPromptCacheForm from 'ee/ai/settings/components/duo_prompt_cache_form.vue';
import DuoFlowSettings from 'ee/ai/settings/components/duo_flow_settings.vue';
import DuoFoundationalAgentsSettings from 'ee/ai/settings/components/duo_foundational_agents_settings.vue';
import DuoAgentPlatformSettingsForm from 'ee/ai/settings/components/duo_agent_platform_settings_form.vue';
import AiNamespaceAccessRules from 'ee/ai/settings/components/ai_namespace_access_rules.vue';
import AiRolePermissions from 'ee/ai/settings/components/ai_role_permissions.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import { mockAgentStatuses } from '../../mocks';

describe('AiCommonSettingsForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCommonSettingsForm, {
      propsData: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        duoCoreFeaturesEnabled: true,
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
        experimentFeaturesEnabled: true,
        promptCacheEnabled: false,
        hasParentFormChanged: false,
        foundationalAgentsEnabled: false,
        selectedFoundationalFlowIds: [],
        foundationalAgentsStatuses: mockAgentStatuses,
        duoAgentPlatformEnabled: true,
        initialNamespaceAccessRules: [],
        duoWorkflowsDefaultImageRegistry: '',
        ...props,
      },
      provide: {
        onGeneralSettingsPage: false,
        initialMinimumAccessLevelExecuteAsync: 30,
        initialMinimumAccessLevelExecuteSync: 10,
        showFoundationalAgentsAvailability: false,
        ...provide,
        glFeatures: {
          dapGroupCustomizablePermissions: false,
          dapInstanceCustomizablePermissions: false,
          ...(provide.glFeatures || {}),
        },
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findDuoAvailability = () => wrapper.findComponent(DuoAvailabilityForm);
  const findDuoExperimentBetaFeatures = () => wrapper.findComponent(DuoExperimentBetaFeaturesForm);
  const findDuoCoreFeaturesForm = () => wrapper.findComponent(DuoCoreFeaturesForm);
  const findDuoPromptCache = () => wrapper.findComponent(DuoPromptCacheForm);
  const findDuoFlowSettings = () => wrapper.findComponent(DuoFlowSettings);
  const findDuoFoundationalAgentsSettings = () =>
    wrapper.findComponent(DuoFoundationalAgentsSettings);
  const findDuoAgentPlatformSettingsForm = () =>
    wrapper.findComponent(DuoAgentPlatformSettingsForm);
  const findAiRolePermissions = () => wrapper.findComponent(AiRolePermissions);
  const findDuoSettingsWarningAlert = () => wrapper.findByTestId('duo-settings-show-warning-alert');
  const findAiNamespaceAccessRules = () => wrapper.findComponent(AiNamespaceAccessRules);
  const findSaveButton = () => wrapper.findComponent(GlButton);

  describe('when initialNamespaceAccessRules is null', () => {
    beforeEach(() => {
      createComponent({ props: { initialNamespaceAccessRules: null } });
    });

    it('does not render the namespace access rules component', () => {
      expect(findAiNamespaceAccessRules().exists()).toBe(false);
    });
  });

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders AI Namespace Access Rules component', () => {
      expect(findAiNamespaceAccessRules().exists()).toBe(true);
    });

    it('renders GlForm component', () => {
      expect(findForm().exists()).toBe(true);
    });

    it('renders the Duo Availability component', () => {
      expect(findDuoAvailability().exists()).toBe(true);
    });

    it('renders the duo core features form', () => {
      expect(findDuoCoreFeaturesForm().exists()).toBe(true);
    });

    it('renders DuoExperimentBetaFeatures component', () => {
      expect(findDuoExperimentBetaFeatures().exists()).toBe(true);
    });

    it('renders DuoPromptCache component', () => {
      expect(findDuoPromptCache().exists()).toBe(true);
    });

    it('renders DuoFlowSettings component', () => {
      expect(findDuoFlowSettings().exists()).toBe(true);
    });

    it('disables save button when no changes are made', () => {
      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('enables save button when changes are made', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
      await findDuoExperimentBetaFeatures().vm.$emit('change', true);
      await findDuoCoreFeaturesForm().vm.$emit('change', true);
      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('enables save button when prompt cache changes are made', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoPromptCache().vm.$emit('change', true);

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('enables save button when duo flow changes are made', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change', true);

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('enables save button when duo foundational flow changes are made', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-foundational-flows', true);

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    describe('when namespace access rules get extended by a group', () => {
      it('enables save button', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findAiNamespaceAccessRules().vm.$emit('change', [
          { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
        ]);

        expect(findSaveButton().props('disabled')).toBe(false);
      });
    });

    describe('when feature gets added to namespace access rule', () => {
      beforeEach(() => {
        createComponent({
          props: {
            initialNamespaceAccessRules: [
              { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
            ],
          },
        });
      });

      it('enables save button', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findAiNamespaceAccessRules().vm.$emit('change', [
          {
            throughNamespace: { id: 1, name: 'group' },
            features: ['duo_agent_platform', 'duo_classic'],
          },
        ]);

        expect(findSaveButton().props('disabled')).toBe(false);
      });
    });

    describe('when features of namespace access rule stay unchanged', () => {
      beforeEach(() => {
        createComponent({
          props: {
            initialNamespaceAccessRules: [
              { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
            ],
          },
        });
      });

      it('save button stays disabled', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findAiNamespaceAccessRules().vm.$emit('change', [
          {
            throughNamespace: { id: 1, name: 'group' },
            features: ['duo_agent_platform'],
          },
        ]);

        expect(findSaveButton().props('disabled')).toBe(true);
      });
    });

    describe('when features of namespace access rule gets removed', () => {
      beforeEach(() => {
        createComponent({
          props: {
            initialNamespaceAccessRules: [
              { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
            ],
          },
        });
      });

      it('enables save button', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findAiNamespaceAccessRules().vm.$emit('change', [
          {
            throughNamespace: { id: 1, name: 'group' },
            features: [],
          },
        ]);

        expect(findSaveButton().props('disabled')).toBe(false);
      });
    });

    describe('when order of features of namespace access rule gets changed', () => {
      beforeEach(() => {
        createComponent({
          props: {
            initialNamespaceAccessRules: [
              {
                throughNamespace: { id: 1, name: 'group' },
                features: ['duo_agent_platform', 'duo_classic'],
              },
            ],
          },
        });
      });

      it('save button stays disabled', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findAiNamespaceAccessRules().vm.$emit('change', [
          {
            throughNamespace: { id: 1, name: 'group' },
            features: ['duo_classic', 'duo_agent_platform'],
          },
        ]);

        expect(findSaveButton().props('disabled')).toBe(true);
      });
    });

    it('enables save button when parent form changes are made', () => {
      createComponent({ props: { hasParentFormChanged: true } });
      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('does not show warning alert when form unchanged', () => {
      expect(findDuoSettingsWarningAlert().exists()).toBe(false);
    });

    it('does not show warning alert when availability is changed to default_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_ON);
      expect(findDuoSettingsWarningAlert().exists()).toBe(false);
    });

    it('shows warning alert when availability is changed to default_off', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
      expect(findDuoSettingsWarningAlert().exists()).toBe(true);
      expect(findDuoSettingsWarningAlert().text()).toContain(
        'When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
      );
    });

    it('shows warning alert when availability is changed to never_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);
      expect(findDuoSettingsWarningAlert().exists()).toBe(true);
      expect(findDuoSettingsWarningAlert().text()).toContain(
        'When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
      );
    });

    it('disables the prompt cache checkbox when duo availability is set to never_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);
      expect(findDuoPromptCache().props('disabledCheckbox')).toBe(true);
    });

    it('disables the duo flow checkbox when duo availability is set to never_on', async () => {
      expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(false);

      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);

      expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(true);
    });
  });

  describe('prompt cache integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits cache-checkbox-changed event when DuoPromptCache emits change', async () => {
      await findDuoPromptCache().vm.$emit('change', true);

      expect(wrapper.emitted('cache-checkbox-changed')[0]).toEqual([true]);
    });

    it('updates internal cacheEnabled data when change event is received', async () => {
      await findDuoPromptCache().vm.$emit('change', true);

      // Verify the form is changed (cacheEnabled is now different from initial prop)
      expect(findSaveButton().props('disabled')).toBe(false);

      // Change it back to initial value
      await findDuoPromptCache().vm.$emit('change', false);

      // Verify the form is unchanged
      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('duo flow integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits duo-flow-checkbox-changed event when DuoFlowSettings emits change', async () => {
      await findDuoFlowSettings().vm.$emit('change', true);

      expect(wrapper.emitted('duo-flow-checkbox-changed')[0]).toEqual([true]);
    });

    it('updates internal flowEnabled data when change event is received', async () => {
      await findDuoFlowSettings().vm.$emit('change', true);

      expect(findSaveButton().props('disabled')).toBe(false);

      await findDuoFlowSettings().vm.$emit('change', false);

      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('duo foundational flow integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits duo-foundational-flows-checkbox-changed event when DuoFlowSettings emits change-foundational-flows', async () => {
      await findDuoFlowSettings().vm.$emit('change-foundational-flows', true);

      expect(wrapper.emitted('duo-foundational-flows-checkbox-changed')[0]).toEqual([true]);
    });

    it('updates internal foundationalFlowsEnabled data when change-foundational-flows event is received', async () => {
      await findDuoFlowSettings().vm.$emit('change-foundational-flows', true);

      expect(findSaveButton().props('disabled')).toBe(false);

      await findDuoFlowSettings().vm.$emit('change-foundational-flows', false);

      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('foundational flow selection integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits change-selected-flow-ids event when DuoFlowSettings emits it', async () => {
      await findDuoFlowSettings().vm.$emit('change-selected-flow-ids', [
        'code_review/v1',
        'bug_triage/v1',
        'documentation/v1',
      ]);

      expect(wrapper.emitted('change-selected-flow-ids')[0]).toEqual([
        ['code_review/v1', 'bug_triage/v1', 'documentation/v1'],
      ]);
    });

    it('updates internal localSelectedFlowIds data when change-selected-flow-ids event is received', async () => {
      createComponent({ props: { selectedFoundationalFlowIds: ['code_review/v1'] } });

      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-selected-flow-ids', [
        'code_review/v1',
        'bug_triage/v1',
      ]);

      expect(findSaveButton().props('disabled')).toBe(false);

      await findDuoFlowSettings().vm.$emit('change-selected-flow-ids', ['code_review/v1']);

      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('enables save button when flow IDs change from empty to non-empty', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-selected-flow-ids', [
        'sast_fp_detection/v1',
        'resolve_sast_vulnerability/v1',
      ]);

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('enables save button when flow IDs order changes', async () => {
      createComponent({
        props: {
          selectedFoundationalFlowIds: ['code_review/v1', 'bug_triage/v1', 'documentation/v1'],
        },
      });

      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-selected-flow-ids', [
        'documentation/v1',
        'bug_triage/v1',
        'code_review/v1',
      ]);

      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('passes selectedFoundationalFlowIds prop to DuoFlowSettings', () => {
      createComponent({
        props: { selectedFoundationalFlowIds: ['code_review/v1', 'bug_triage/v1'] },
      });

      expect(findDuoFlowSettings().props('selectedFoundationalFlowIds')).toEqual([
        'code_review/v1',
        'bug_triage/v1',
      ]);
    });
  });

  describe('duo workflows default image registry integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits change-default-image-registry event when DuoFlowSettings emits it', async () => {
      await findDuoFlowSettings().vm.$emit('change-default-image-registry', 'registry.example.com');

      expect(wrapper.emitted('change-default-image-registry')[0]).toEqual(['registry.example.com']);
    });

    it('updates internal localDefaultImageRegistry data when change-default-image-registry event is received', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-default-image-registry', 'registry.example.com');

      expect(findSaveButton().props('disabled')).toBe(false);

      await findDuoFlowSettings().vm.$emit('change-default-image-registry', '');

      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('enables save button when default image registry changes', async () => {
      createComponent({ props: { duoWorkflowsDefaultImageRegistry: 'registry.example.com' } });

      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-default-image-registry', 'registry.test.com');

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('passes duoWorkflowsDefaultImageRegistry prop to DuoFlowSettings', () => {
      createComponent({ props: { duoWorkflowsDefaultImageRegistry: 'registry.example.com' } });

      expect(findDuoFlowSettings().props('duoWorkflowsDefaultImageRegistry')).toEqual(
        'registry.example.com',
      );
    });
  });

  describe('with onGeneralSettingsPage true', () => {
    beforeEach(() => {
      createComponent({ provide: { onGeneralSettingsPage: true } });
    });

    it('does not render the Duo Core features form', () => {
      expect(findDuoCoreFeaturesForm().exists()).toBe(false);
    });

    it('does not render the namespace access rules component', () => {
      expect(findAiNamespaceAccessRules().exists()).toBe(false);
    });
  });

  describe('foundational agents settings', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render the setting when showFoundationalAgentsAvailability is false', () => {
      expect(findDuoFoundationalAgentsSettings().exists()).toBe(false);
    });

    describe('when showFoundationalAgentsAvailability is true', () => {
      beforeEach(() => {
        createComponent({
          props: { foundationalAgentsEnabled: false },
          provide: { showFoundationalAgentsAvailability: true },
        });
      });

      it('renders setting when showFoundationalAgentsAvailability is true', () => {
        expect(findDuoFoundationalAgentsSettings().exists()).toBe(true);
        expect(findDuoFoundationalAgentsSettings().props('enabled')).toEqual(false);
      });

      it('passes foundationalAgentsStatuses to the component', () => {
        expect(findDuoFoundationalAgentsSettings().props('agentStatuses')).toEqual(
          mockAgentStatuses,
        );
      });

      it('emits duo-foundational-agents-changed event when DuoFoundationalAgentsSettings emits change', async () => {
        findDuoFoundationalAgentsSettings().vm.$emit('change', true);
        await nextTick();

        expect(wrapper.emitted('duo-foundational-agents-changed')).toHaveLength(1);
        expect(wrapper.emitted('duo-foundational-agents-changed')[0]).toEqual([true]);
      });

      it('enables save button when foundational agent enabled value changes', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findDuoFoundationalAgentsSettings().vm.$emit('change', true);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('keeps save button disabled when foundational agents enabled value is unchanged', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findDuoFoundationalAgentsSettings().vm.$emit('change', false);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(true);
      });

      describe('for per agent settings', () => {
        const updatedStatuses = [
          { reference: 'security-analyst', name: 'Security Analyst', enabled: false },
          { reference: 'code-reviewer', name: 'Code Reviewer', enabled: false },
        ];

        it('emits duo-foundational-agents-statuses-change event when agent is toggled', async () => {
          findDuoFoundationalAgentsSettings().vm.$emit('agent-toggle', updatedStatuses);
          await nextTick();

          expect(wrapper.emitted('duo-foundational-agents-statuses-change')).toHaveLength(1);
          expect(wrapper.emitted('duo-foundational-agents-statuses-change')[0]).toEqual([
            updatedStatuses,
          ]);
        });

        it('enables save button when agent statuses change', async () => {
          expect(findSaveButton().props('disabled')).toBe(true);

          findDuoFoundationalAgentsSettings().vm.$emit('agent-toggle', updatedStatuses);
          await nextTick();

          expect(findSaveButton().props('disabled')).toBe(false);
        });
      });
    });
  });

  describe('duo agent platform settings', () => {
    it.each([true, false])('renders form with correct enabled prop', (value) => {
      createComponent({ props: { duoAgentPlatformEnabled: value } });
      expect(findDuoAgentPlatformSettingsForm().props('enabled')).toBe(value);
    });

    it('emits duo-agent-platform-enabled-changed event when DuoAgentPlatformSettingsForm emits selected', async () => {
      createComponent();
      findDuoAgentPlatformSettingsForm().vm.$emit('selected', false);
      await nextTick();

      expect(wrapper.emitted('duo-agent-platform-enabled-changed')).toHaveLength(1);
      expect(wrapper.emitted('duo-agent-platform-enabled-changed')[0]).toEqual([false]);
    });

    it('enables save button when duo agent platform enabled value changes', async () => {
      createComponent();
      expect(findSaveButton().props('disabled')).toBe(true);

      findDuoAgentPlatformSettingsForm().vm.$emit('selected', false);
      await nextTick();

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('keeps save button disabled when duo agent platform enabled value is unchanged', async () => {
      createComponent();
      expect(findSaveButton().props('disabled')).toBe(true);

      findDuoAgentPlatformSettingsForm().vm.$emit('selected', true);
      await nextTick();

      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('AI Role Permissions', () => {
    it('does not render when both feature flags are disabled', () => {
      createComponent({
        provide: {
          isSaaS: true,
          glFeatures: {
            dapGroupCustomizablePermissions: false,
            dapInstanceCustomizablePermissions: false,
          },
        },
      });

      expect(findAiRolePermissions().exists()).toBe(false);
    });

    it('does not render on SaaS when only instance flag is enabled', () => {
      createComponent({
        provide: {
          isSaaS: true,
          glFeatures: {
            dapGroupCustomizablePermissions: false,
            dapInstanceCustomizablePermissions: true,
          },
        },
      });

      expect(findAiRolePermissions().exists()).toBe(false);
    });

    it('does not render on Self-Managed when only group flag is enabled', () => {
      createComponent({
        provide: {
          isSaaS: false,
          glFeatures: {
            dapGroupCustomizablePermissions: true,
            dapInstanceCustomizablePermissions: false,
          },
        },
      });

      expect(findAiRolePermissions().exists()).toBe(false);
    });

    describe('when dapGroupCustomizablePermissions is enabled on SaaS', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isSaaS: true,
            initialMinimumAccessLevelExecuteAsync: 30,
            initialMinimumAccessLevelExecuteSync: 10,
            glFeatures: {
              dapGroupCustomizablePermissions: true,
            },
          },
        });
      });

      it('renders AiRolePermissions component', () => {
        expect(findAiRolePermissions().exists()).toBe(true);
      });

      it('passes correct initial props', () => {
        expect(findAiRolePermissions().props()).toMatchObject({
          initialMinimumAccessLevelExecuteAsync: 30,
          initialMinimumAccessLevelExecuteSync: 10,
        });
      });

      it('enables save button when minimum access level execute async changes', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findAiRolePermissions().vm.$emit('minimum-access-level-execute-async-change', 40);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('enables save button when minimum access level execute sync changes', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findAiRolePermissions().vm.$emit('minimum-access-level-execute-sync-change', 20);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('emits minimum-access-level-execute-async-changed event when AiRolePermissions emits change', async () => {
        findAiRolePermissions().vm.$emit('minimum-access-level-execute-async-change', 40);
        await nextTick();

        expect(wrapper.emitted('minimum-access-level-execute-async-changed')).toEqual([[40]]);
      });

      it('emits minimum-access-level-execute-sync-changed event when AiRolePermissions emits change', async () => {
        findAiRolePermissions().vm.$emit('minimum-access-level-execute-sync-change', 20);
        await nextTick();

        expect(wrapper.emitted('minimum-access-level-execute-sync-changed')).toEqual([[20]]);
      });
    });

    describe('when dapInstanceCustomizablePermissions is enabled on Self-Managed', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isSaaS: false,
            initialMinimumAccessLevelExecuteAsync: 30,
            initialMinimumAccessLevelExecuteSync: 10,
            glFeatures: {
              dapInstanceCustomizablePermissions: true,
            },
          },
        });
      });

      it('renders AiRolePermissions component', () => {
        expect(findAiRolePermissions().exists()).toBe(true);
      });

      it('passes correct initial props', () => {
        expect(findAiRolePermissions().props()).toMatchObject({
          initialMinimumAccessLevelExecuteAsync: 30,
          initialMinimumAccessLevelExecuteSync: 10,
        });
      });

      it('enables save button when minimum access level execute async changes', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findAiRolePermissions().vm.$emit('minimum-access-level-execute-async-change', 40);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('enables save button when minimum access level execute sync changes', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findAiRolePermissions().vm.$emit('minimum-access-level-execute-sync-change', 20);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(false);
      });
    });

    describe('when on SaaS and general settings page with enabled FF', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isSaaS: true,
            glFeatures: {
              dapGroupCustomizablePermissions: true,
            },
            onGeneralSettingsPage: true,
          },
        });
      });

      it('does not render AiRolePermissions component', () => {
        expect(findAiRolePermissions().exists()).toBe(false);
      });
    });

    describe('when on Self-Managed and general settings page with enabled FF', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isSaaS: false,
            glFeatures: {
              dapInstanceCustomizablePermissions: true,
            },
            onGeneralSettingsPage: true,
          },
        });
      });

      it('does not render AiRolePermissions component', () => {
        expect(findAiRolePermissions().exists()).toBe(false);
      });
    });
  });
});
