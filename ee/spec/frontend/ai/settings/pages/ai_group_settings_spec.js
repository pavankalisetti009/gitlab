import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { updateGroupSettings } from 'ee/api/groups_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiGroupSettings from 'ee/ai/settings/pages/ai_group_settings.vue';
import DuoWorkflowSettingsForm from 'ee/ai/settings/components/duo_workflow_settings_form.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import { mockAgentStatuses, expectedFilteredAgentStatuses } from '../../mocks';

jest.mock('ee/api/groups_api');
jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

jest.mock('ee/ai/settings/components/early_access_program_banner.vue', () => ({
  name: 'EarlyAccessProgramBanner',
  render: (h) => h('early-access-program-banner'),
}));

let wrapper;

const createComponent = ({ props = {}, provide = {} } = {}) => {
  wrapper = shallowMount(AiGroupSettings, {
    propsData: {
      redirectPath: '/groups/test-group',
      updateId: '100',
      ...props,
    },
    provide: {
      showEarlyAccessBanner: false,
      onGeneralSettingsPage: false,
      duoWorkflowAvailable: true,
      duoWorkflowMcpEnabled: false,
      promptInjectionProtectionLevel: 'interrupt',
      promptInjectionProtectionAvailable: true,
      availableFoundationalFlows: [],
      ...provide,
    },
  });
};

const findAiCommonSettings = () => wrapper.findComponent(AiCommonSettings);
const findEarlyAccessBanner = () => wrapper.findComponent({ name: 'EarlyAccessProgramBanner' });
const findDuoWorkflowSettingsForm = () => wrapper.findComponent(DuoWorkflowSettingsForm);

describe('AiGroupSettings', () => {
  beforeEach(() => {
    createComponent();
  });

  describe('UI', () => {
    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('renders DuoWorkflowSettingsForm component when duoWorkflowAvailable is true', () => {
      createComponent({ provide: { duoWorkflowAvailable: true } });
      expect(findDuoWorkflowSettingsForm().exists()).toBe(true);
    });

    it('does not render DuoWorkflowSettingsForm component when both are unavailable', () => {
      createComponent({
        provide: { duoWorkflowAvailable: false, promptInjectionProtectionAvailable: false },
      });
      expect(findDuoWorkflowSettingsForm().exists()).toBe(false);
    });

    it('renders DuoWorkflowSettingsForm with only MCP when protection is unavailable', () => {
      createComponent({ provide: { promptInjectionProtectionAvailable: false } });
      expect(findDuoWorkflowSettingsForm().exists()).toBe(true);
      expect(findDuoWorkflowSettingsForm().props('showMcp')).toBe(true);
      expect(findDuoWorkflowSettingsForm().props('showProtection')).toBe(false);
    });

    it('renders DuoWorkflowSettingsForm with only protection when MCP is unavailable', () => {
      createComponent({ provide: { duoWorkflowAvailable: false } });
      expect(findDuoWorkflowSettingsForm().exists()).toBe(true);
      expect(findDuoWorkflowSettingsForm().props('showMcp')).toBe(false);
      expect(findDuoWorkflowSettingsForm().props('showProtection')).toBe(true);
    });

    it('passes correct props to DuoWorkflowSettingsForm when rendered', () => {
      createComponent({ provide: { duoWorkflowAvailable: true } });
      expect(findDuoWorkflowSettingsForm().props('isMcpEnabled')).toBe(false);
      expect(findDuoWorkflowSettingsForm().props('promptInjectionProtectionLevel')).toBe(
        'interrupt',
      );
    });

    it('passes hasFormChanged prop to AiCommonSettings', () => {
      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
    });
  });

  describe('when showEarlyAccessBanner setting is set', () => {
    it('does not render the banner when the cookie is missing', () => {
      expect(findEarlyAccessBanner().exists()).toBe(false);
    });

    it('is true it renders EarlyAccessProgramBanner', async () => {
      createComponent({ provide: { showEarlyAccessBanner: true } });
      await nextTick();
      await nextTick();
      expect(findEarlyAccessBanner().exists()).toBe(true);
    });
  });

  describe('data initialization', () => {
    it('initializes duoWorkflowMcp from injected value', () => {
      createComponent({ provide: { duoWorkflowMcpEnabled: true } });
      expect(findDuoWorkflowSettingsForm().props('isMcpEnabled')).toBe(true);
    });

    it('initializes promptInjectionProtection from injected value', () => {
      createComponent({ provide: { promptInjectionProtectionLevel: 'log_only' } });
      expect(findDuoWorkflowSettingsForm().props('promptInjectionProtectionLevel')).toBe(
        'log_only',
      );
    });
  });

  describe('computed properties', () => {
    describe('hasFormChanged', () => {
      it('returns false when duoWorkflowMcp and promptInjectionProtection match injected values', () => {
        createComponent({
          provide: {
            duoWorkflowMcpEnabled: false,
            promptInjectionProtectionLevel: 'interrupt',
          },
        });
        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
      });

      it('returns true when duoWorkflowMcp differs from injected value', async () => {
        createComponent({ provide: { duoWorkflowMcpEnabled: false } });
        findDuoWorkflowSettingsForm().vm.$emit('mcp-change', true);

        await nextTick();

        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
      });

      it('returns true when promptInjectionProtection differs from injected value', async () => {
        createComponent({ provide: { promptInjectionProtectionLevel: 'interrupt' } });
        findDuoWorkflowSettingsForm().vm.$emit('protection-level-change', 'log_only');

        await nextTick();

        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
      });
    });

    describe('showWorkflowSettingsForm', () => {
      it.each([
        {
          description: 'when duoWorkflowAvailable is true',
          provide: { duoWorkflowAvailable: true },
          shouldRender: true,
        },
        {
          description: 'when promptInjectionProtectionAvailable is true',
          provide: { promptInjectionProtectionAvailable: true },
          shouldRender: true,
        },
        {
          description: 'when both are unavailable',
          provide: { duoWorkflowAvailable: false, promptInjectionProtectionAvailable: false },
          shouldRender: false,
        },
      ])('$description', ({ provide, shouldRender }) => {
        createComponent({ provide });
        expect(findDuoWorkflowSettingsForm().exists()).toBe(shouldRender);
      });
    });
  });

  describe('methods', () => {
    describe('onDuoWorkflowMcpChanged', () => {
      describe('when mcp-change event is emitted', () => {
        it('updates duoWorkflowMcp value and marks form as changed', async () => {
          expect(findDuoWorkflowSettingsForm().props('isMcpEnabled')).toBe(false);
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);

          findDuoWorkflowSettingsForm().vm.$emit('mcp-change', true);
          await nextTick();

          expect(findDuoWorkflowSettingsForm().props('isMcpEnabled')).toBe(true);
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
        });
      });
    });

    describe('onPromptInjectionProtectionChanged', () => {
      describe('when protection-level-change event is emitted', () => {
        it('updates promptInjectionProtection value and marks form as changed', async () => {
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
          expect(findDuoWorkflowSettingsForm().props('promptInjectionProtectionLevel')).toBe(
            'interrupt',
          );

          findDuoWorkflowSettingsForm().vm.$emit('protection-level-change', 'log_only');
          await nextTick();

          expect(findDuoWorkflowSettingsForm().props('promptInjectionProtectionLevel')).toBe(
            'log_only',
          );
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
        });
      });
    });
  });

  describe('updateSettings', () => {
    it('calls updateGroupSettings with correct parameters', async () => {
      updateGroupSettings.mockResolvedValue({});
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: true,
        duoCoreFeaturesEnabled: true,
        promptCacheEnabled: true,
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
        duoSastFpDetectionAvailability: false,
        foundationalAgentsEnabled: true,
        foundationalAgentsStatuses: mockAgentStatuses,
        selectedFoundationalFlowIds: [],
        duoAgentPlatformEnabled: true,
      });
      expect(updateGroupSettings).toHaveBeenCalledTimes(1);
      expect(updateGroupSettings).toHaveBeenCalledWith('100', {
        duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experiment_features_enabled: true,
        duo_core_features_enabled: true,
        model_prompt_cache_enabled: true,
        duo_remote_flows_availability: false,
        duo_foundational_flows_availability: false,
        duo_sast_fp_detection_availability: false,
        foundational_agents_statuses: expectedFilteredAgentStatuses,
        enabled_foundational_flows: [],
        ai_settings_attributes: {
          duo_agent_platform_enabled: true,
          duo_workflow_mcp_enabled: false,
          prompt_injection_protection_level: 'interrupt',
          foundational_agents_default_enabled: true,
        },
      });
    });

    describe('when duoWorkflowMcp is changed', () => {
      beforeEach(async () => {
        updateGroupSettings.mockResolvedValue({});
        findDuoWorkflowSettingsForm().vm.$emit('mcp-change', true);
        await nextTick();
      });

      it('includes updated duoWorkflowMcp value in API call', async () => {
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: true,
          duoCoreFeaturesEnabled: true,
          promptCacheEnabled: true,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          duoSastFpDetectionAvailability: false,
          selectedFoundationalFlowIds: [],
        });
        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.objectContaining({
            enabled_foundational_flows: [],
            ai_settings_attributes: {
              duo_workflow_mcp_enabled: true,
              prompt_injection_protection_level: 'interrupt',
            },
          }),
        );
      });
    });

    describe('when promptInjectionProtection is changed', () => {
      beforeEach(async () => {
        updateGroupSettings.mockResolvedValue({});
        findDuoWorkflowSettingsForm().vm.$emit('protection-level-change', 'log_only');
        await nextTick();
      });

      it('includes updated promptInjectionProtection value in API call', async () => {
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: true,
          duoCoreFeaturesEnabled: true,
          promptCacheEnabled: true,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          duoSastFpDetectionAvailability: false,
          selectedFoundationalFlowIds: [],
        });
        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.objectContaining({
            enabled_foundational_flows: [],
            ai_settings_attributes: {
              duo_workflow_mcp_enabled: false,
              prompt_injection_protection_level: 'log_only',
            },
          }),
        );
      });
    });

    describe('when update succeeds', () => {
      beforeEach(async () => {
        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: false,
          duoCoreFeaturesEnabled: false,
          promptCacheEnabled: false,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          duoSastFpDetectionAvailability: false,
          selectedFoundationalFlowIds: [],
        });
        await waitForPromises();
      });

      it('shows success message', () => {
        expect(visitUrlWithAlerts).toHaveBeenCalledWith(
          expect.any(String),
          expect.arrayContaining([
            expect.objectContaining({
              id: 'organization-group-successfully-updated',
              message: 'Group was successfully updated.',
              variant: VARIANT_INFO,
            }),
          ]),
        );
      });
    });

    describe('when update fails', () => {
      beforeEach(async () => {
        const error = new Error('API error');
        updateGroupSettings.mockRejectedValue(error);
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: false,
          duoCoreFeaturesEnabled: false,
          promptCacheEnabled: true,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          duoSastFpDetectionAvailability: false,
          selectedFoundationalFlowIds: [],
        });
        await waitForPromises();
      });

      it('shows error message', () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message:
              'An error occurred while retrieving your settings. Reload the page to try again.',
            captureError: true,
            error: expect.any(Error),
          }),
        );
      });
    });

    describe('when on general settings section', () => {
      beforeEach(async () => {
        createComponent({ provide: { onGeneralSettingsPage: true } });
        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: false,
          duoCoreFeaturesEnabled: true,
          promptCacheEnabled: true,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          duoSastFpDetectionAvailability: false,
          selectedFoundationalFlowIds: [],
        });
      });

      it('does not update duo core setting', () => {
        expect(updateGroupSettings).toHaveBeenCalledTimes(1);
        expect(updateGroupSettings).toHaveBeenCalledWith('100', {
          duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experiment_features_enabled: false,
          model_prompt_cache_enabled: true,
          duo_remote_flows_availability: false,
          duo_foundational_flows_availability: false,
          duo_sast_fp_detection_availability: false,
          enabled_foundational_flows: [],
          ai_settings_attributes: {
            duo_workflow_mcp_enabled: false,
            prompt_injection_protection_level: 'interrupt',
          },
        });
        expect(updateGroupSettings).not.toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            duo_core_features_enabled: expect.anything(),
          }),
        );
      });
    });

    describe('foundational flow selection', () => {
      describe('when selectedFoundationalFlowIds are provided', () => {
        beforeEach(async () => {
          updateGroupSettings.mockResolvedValue({});
          await findAiCommonSettings().vm.$emit('submit', {
            duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
            experimentFeaturesEnabled: false,
            duoCoreFeaturesEnabled: false,
            promptCacheEnabled: false,
            duoRemoteFlowsAvailability: false,
            duoFoundationalFlowsAvailability: false,
            duoSastFpDetectionAvailability: false,
            selectedFoundationalFlowIds: [1, 2, 3],
          });
        });

        it('passes selectedFoundationalFlowIds to API', () => {
          expect(updateGroupSettings).toHaveBeenCalledWith(
            '100',
            expect.objectContaining({
              enabled_foundational_flows: [1, 2, 3],
            }),
          );
        });
      });
    });
  });
});
