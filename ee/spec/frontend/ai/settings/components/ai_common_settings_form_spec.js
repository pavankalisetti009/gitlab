import { nextTick } from 'vue';
import { GlForm, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCommonSettingsForm from 'ee/ai/settings/components/ai_common_settings_form.vue';
import DuoAvailabilityForm from 'ee/ai/settings/components/duo_availability_form.vue';
import DuoExperimentBetaFeaturesForm from 'ee/ai/settings/components/duo_experiment_beta_features_form.vue';
import DuoCoreFeaturesForm from 'ee/ai/settings/components/duo_core_features_form.vue';
import DuoPromptCacheForm from 'ee/ai/settings/components/duo_prompt_cache_form.vue';
import DuoFlowSettings from 'ee/ai/settings/components/duo_flow_settings.vue';
import DuoSastFpDetectionSettings from 'ee/ai/settings/components/duo_sast_fp_detection_settings.vue';
import DuoFoundationalAgentsSettings from 'ee/ai/settings/components/duo_foundational_agents_settings.vue';
import DuoAgentPlatformSettingsForm from 'ee/ai/settings/components/duo_agent_platform_settings_form.vue';
import AiNamespaceAccessRules from 'ee/ai/settings/components/ai_namespace_access_rules.vue';
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
        duoSastFpDetectionAvailability: false,
        experimentFeaturesEnabled: true,
        promptCacheEnabled: false,
        hasParentFormChanged: false,
        foundationalAgentsEnabled: false,
        selectedFoundationalFlowIds: [],
        foundationalAgentsStatuses: mockAgentStatuses,
        duoAgentPlatformEnabled: true,
        initialNamespaceAccessRules: [],
        ...props,
      },
      provide: {
        onGeneralSettingsPage: false,
        showFoundationalAgentsAvailability: false,
        ...provide,
        glFeatures: {
          aiExperimentSastFpDetection: true,
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
  const findDuoSastFpDetectionSettings = () => wrapper.findComponent(DuoSastFpDetectionSettings);
  const findDuoFoundationalAgentsSettings = () =>
    wrapper.findComponent(DuoFoundationalAgentsSettings);
  const findDuoAgentPlatformSettingsForm = () =>
    wrapper.findComponent(DuoAgentPlatformSettingsForm);
  const findDuoSettingsWarningAlert = () => wrapper.findByTestId('duo-settings-show-warning-alert');
  const findAiNamespaceAccessRules = () => wrapper.findComponent(AiNamespaceAccessRules);
  const findSaveButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders AI Namespace Access Rules component', () => {
      expect(findAiNamespaceAccessRules().exists()).toBe(true);
    });

    describe('when initialNamespaceAccessRules is null', () => {
      beforeEach(() => {
        createComponent({ props: { initialNamespaceAccessRules: null } });
      });

      it('does not render the component', () => {
        expect(findAiNamespaceAccessRules().exists()).toBe(false);
      });
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

    it('renders DuoSastFpDetectionSettings component', () => {
      expect(findDuoSastFpDetectionSettings().exists()).toBe(true);
    });

    describe('when aiExperimentSastFpDetection feature flag is disabled', () => {
      let wrapperWithDisabledFlag;

      const createComponentWithDisabledFlag = (props = {}, provide = {}) => {
        return shallowMountExtended(AiCommonSettingsForm, {
          propsData: {
            duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
            duoCoreFeaturesEnabled: true,
            duoRemoteFlowsAvailability: false,
            duoFoundationalFlowsAvailability: false,
            duoSastFpDetectionAvailability: false,
            experimentFeaturesEnabled: true,
            promptCacheEnabled: false,
            hasParentFormChanged: false,
            foundationalAgentsEnabled: false,
            foundationalAgentsStatuses: mockAgentStatuses,
            duoAgentPlatformEnabled: true,
            initialNamespaceAccessRules: [],
            selectedFoundationalFlowIds: [],
            ...props,
          },
          provide: {
            onGeneralSettingsPage: false,
            showFoundationalAgentsAvailability: false,
            glFeatures: {
              aiExperimentSastFpDetection: false,
            },
            ...provide,
          },
        });
      };

      beforeEach(() => {
        wrapperWithDisabledFlag = createComponentWithDisabledFlag();
      });

      afterEach(() => {
        if (wrapperWithDisabledFlag) {
          wrapperWithDisabledFlag.destroy();
        }
      });

      it('does not render DuoSastFpDetectionSettings component', () => {
        expect(wrapperWithDisabledFlag.findComponent(DuoSastFpDetectionSettings).exists()).toBe(
          false,
        );
      });

      it('save button is enabled when other form changes are made', async () => {
        expect(wrapperWithDisabledFlag.findComponent(GlButton).props('disabled')).toBe(true);

        await wrapperWithDisabledFlag.findComponent(DuoFlowSettings).vm.$emit('change', true);

        expect(wrapperWithDisabledFlag.findComponent(GlButton).props('disabled')).toBe(false);
      });

      it('does not include SAST FP detection changes in form validation', async () => {
        expect(wrapperWithDisabledFlag.findComponent(GlButton).props('disabled')).toBe(true);

        // Change availability which should enable save button
        await wrapperWithDisabledFlag
          .findComponent(DuoAvailabilityForm)
          .vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);

        expect(wrapperWithDisabledFlag.findComponent(GlButton).props('disabled')).toBe(false);
      });
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

    it('enables save button when duo SAST FP detection changes are made', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoSastFpDetectionSettings().vm.$emit('change', true);

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

    it('enables save button when duo SAST FP detection changes are made (feature flag enabled)', async () => {
      createComponent({}, { glFeatures: { aiExperimentSastFpDetection: true } });

      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoSastFpDetectionSettings().vm.$emit('change', true);

      expect(findSaveButton().props('disabled')).toBe(false);
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

    it('disables the duo SAST FP detection checkbox when duo availability is set to never_on', async () => {
      expect(findDuoSastFpDetectionSettings().props('disabledCheckbox')).toBe(false);

      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);

      expect(findDuoSastFpDetectionSettings().props('disabledCheckbox')).toBe(true);
    });

    it('does not disable SAST FP detection when feature flag is disabled', async () => {
      const wrapperDisabled = shallowMountExtended(AiCommonSettingsForm, {
        propsData: {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
          duoCoreFeaturesEnabled: true,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          duoSastFpDetectionAvailability: false,
          experimentFeaturesEnabled: true,
          promptCacheEnabled: false,
          hasParentFormChanged: false,
          foundationalAgentsEnabled: false,
          foundationalAgentsStatuses: mockAgentStatuses,
          duoAgentPlatformEnabled: true,
          initialNamespaceAccessRules: [],
          selectedFoundationalFlowIds: [],
        },
        provide: {
          onGeneralSettingsPage: false,
          showFoundationalAgentsAvailability: false,
          glFeatures: {
            aiExperimentSastFpDetection: false,
          },
        },
      });

      expect(wrapperDisabled.findComponent(DuoSastFpDetectionSettings).exists()).toBe(false);

      await wrapperDisabled
        .findComponent(DuoAvailabilityForm)
        .vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);

      // Component should still not exist
      expect(wrapperDisabled.findComponent(DuoSastFpDetectionSettings).exists()).toBe(false);

      wrapperDisabled.destroy();
    });
  });

  describe('prompt cache integration', () => {
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

  describe('duo SAST FP detection integration', () => {
    it('emits duo-sast-fp-detection-changed event when DuoSastFpDetectionSettings emits change', async () => {
      await findDuoSastFpDetectionSettings().vm.$emit('change', true);

      expect(wrapper.emitted('duo-sast-fp-detection-changed')[0]).toEqual([true]);
    });

    it('updates internal sastFpDetectionEnabled data when change event is received', async () => {
      await findDuoSastFpDetectionSettings().vm.$emit('change', true);

      expect(findSaveButton().props('disabled')).toBe(false);

      await findDuoSastFpDetectionSettings().vm.$emit('change', false);

      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('duo flow integration', () => {
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

  describe('with onGeneralSettingsPage true', () => {
    it('does not render the Duo Core features form', () => {
      createComponent({ provide: { onGeneralSettingsPage: true } });
      expect(findDuoCoreFeaturesForm().exists()).toBe(false);
    });
  });

  describe('foundational agents settings', () => {
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
      findDuoAgentPlatformSettingsForm().vm.$emit('selected', false);
      await nextTick();

      expect(wrapper.emitted('duo-agent-platform-enabled-changed')).toHaveLength(1);
      expect(wrapper.emitted('duo-agent-platform-enabled-changed')[0]).toEqual([false]);
    });

    it('enables save button when duo agent platform enabled value changes', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      findDuoAgentPlatformSettingsForm().vm.$emit('selected', false);
      await nextTick();

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('keeps save button disabled when duo agent platform enabled value is unchanged', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      findDuoAgentPlatformSettingsForm().vm.$emit('selected', true);
      await nextTick();

      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });
});
