<script>
import { updateGroupSettings } from 'ee/api/groups_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __ } from '~/locale';
import { ACCESS_LEVEL_EVERYONE_INTEGER } from '../constants';
import AiCommonSettings from '../components/ai_common_settings.vue';
import DuoWorkflowSettingsForm from '../components/duo_workflow_settings_form.vue';
import AiUsageDataCollectionForm from '../components/ai_usage_data_collection_form.vue';

export default {
  name: 'AiGroupSettings',
  components: {
    AiCommonSettings,
    DuoWorkflowSettingsForm,
    AiUsageDataCollectionForm,
  },
  i18n: {
    successMessage: __('Group was successfully updated.'),
    errorMessage: __(
      'An error occurred while retrieving your settings. Reload the page to try again.',
    ),
  },
  inject: [
    'onGeneralSettingsPage',
    'duoWorkflowAvailable',
    'duoWorkflowMcpEnabled',
    'aiUsageDataCollectionAvailable',
    'aiUsageDataCollectionEnabled',
    'promptInjectionProtectionLevel',
    'promptInjectionProtectionAvailable',
    'availableFoundationalFlows',
    'initialMinimumAccessLevelExecuteAsync',
    'initialMinimumAccessLevelExecuteSync',
  ],
  props: {
    redirectPath: {
      type: String,
      required: false,
      default: '',
    },
    updateId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      duoWorkflowMcp: this.duoWorkflowMcpEnabled,
      aiUsageDataCollection: this.aiUsageDataCollectionEnabled,
      promptInjectionProtection: this.promptInjectionProtectionLevel,
      minimumAccessLevelExecuteAsync: this.initialMinimumAccessLevelExecuteAsync,
      minimumAccessLevelExecuteSync: this.initialMinimumAccessLevelExecuteSync,
    };
  },
  computed: {
    hasFormChanged() {
      return (
        this.duoWorkflowMcpEnabled !== this.duoWorkflowMcp ||
        this.aiUsageDataCollectionEnabled !== this.aiUsageDataCollection ||
        this.promptInjectionProtectionLevel !== this.promptInjectionProtection
      );
    },
    showWorkflowSettingsForm() {
      return this.duoWorkflowAvailable || this.promptInjectionProtectionAvailable;
    },
    hasMinimumAccessLevelExecuteAsyncChanged() {
      return this.minimumAccessLevelExecuteAsync !== this.initialMinimumAccessLevelExecuteAsync;
    },
    hasMinimumAccessLevelExecuteSyncChanged() {
      return this.minimumAccessLevelExecuteSync !== this.initialMinimumAccessLevelExecuteSync;
    },
  },
  methods: {
    async updateSettings({
      duoAvailability,
      duoRemoteFlowsAvailability,
      experimentFeaturesEnabled,
      duoCoreFeaturesEnabled,
      promptCacheEnabled,
      duoFoundationalFlowsAvailability,
      foundationalAgentsEnabled,
      foundationalAgentsStatuses,
      selectedFoundationalFlowIds,
      duoAgentPlatformEnabled,
      namespaceAccessRules,
      minimumAccessLevelExecuteSync,
      minimumAccessLevelExecuteAsync,
    }) {
      try {
        const transformedFoundationalAgentsStatuses = foundationalAgentsStatuses?.filter(
          (agent) => agent.enabled !== null,
        );

        this.minimumAccessLevelExecuteSync = minimumAccessLevelExecuteSync;
        this.minimumAccessLevelExecuteAsync = minimumAccessLevelExecuteAsync;

        const input = {
          duo_availability: duoAvailability,
          experiment_features_enabled: experimentFeaturesEnabled,
          model_prompt_cache_enabled: promptCacheEnabled,
          duo_remote_flows_availability: duoRemoteFlowsAvailability,
          duo_foundational_flows_availability: duoFoundationalFlowsAvailability,
          enabled_foundational_flows: selectedFoundationalFlowIds,
          ...(foundationalAgentsStatuses && {
            foundational_agents_statuses: transformedFoundationalAgentsStatuses,
          }),
          ai_settings_attributes: {
            duo_agent_platform_enabled: duoAgentPlatformEnabled,
            ...(this.duoWorkflowAvailable && {
              duo_workflow_mcp_enabled: this.duoWorkflowMcp,
            }),
            ai_usage_data_collection_enabled: this.aiUsageDataCollection,
            ...(this.promptInjectionProtectionAvailable && {
              prompt_injection_protection_level: this.promptInjectionProtection,
            }),
            foundational_agents_default_enabled: foundationalAgentsEnabled,
          },
        };

        if (this.hasMinimumAccessLevelExecuteSyncChanged) {
          input.ai_settings_attributes.minimum_access_level_execute =
            this.convertMinimumAccessLevelExecuteSync(minimumAccessLevelExecuteSync);
        }

        if (this.hasMinimumAccessLevelExecuteAsyncChanged) {
          input.ai_settings_attributes.minimum_access_level_execute_async =
            minimumAccessLevelExecuteAsync;
        }

        if (!this.onGeneralSettingsPage) {
          input.duo_core_features_enabled = duoCoreFeaturesEnabled;
          if (namespaceAccessRules !== undefined) {
            input.duo_namespace_access_rules =
              this.formatNamespaceAccessRules(namespaceAccessRules);
          }
        }

        await updateGroupSettings(this.updateId, input);

        visitUrlWithAlerts(this.redirectPath, [
          {
            id: 'organization-group-successfully-updated',
            message: this.$options.i18n.successMessage,
            variant: VARIANT_INFO,
          },
        ]);
      } catch (error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          captureError: true,
          error,
        });
      }
    },
    onDuoWorkflowMcpChanged(value) {
      this.duoWorkflowMcp = value;
    },
    onAiUsageDataCollectionChanged(value) {
      this.aiUsageDataCollection = value;
    },
    onPromptInjectionProtectionChanged(value) {
      this.promptInjectionProtection = value;
    },
    formatNamespaceAccessRules(rules) {
      if (!rules) return [];

      return rules.map((rule) => ({
        through_namespace: {
          id: rule.throughNamespace.id,
        },
        features: rule.features,
      }));
    },
    convertMinimumAccessLevelExecuteSync(value) {
      if (value === ACCESS_LEVEL_EVERYONE_INTEGER) {
        return null;
      }

      return value;
    },
  },
};
</script>
<template>
  <ai-common-settings :has-parent-form-changed="hasFormChanged" @submit="updateSettings">
    <template #ai-common-settings-bottom>
      <ai-usage-data-collection-form
        v-if="aiUsageDataCollectionAvailable"
        @change="onAiUsageDataCollectionChanged"
      />
      <duo-workflow-settings-form
        v-if="showWorkflowSettingsForm"
        :is-mcp-enabled="duoWorkflowMcp"
        :show-mcp="duoWorkflowAvailable"
        :prompt-injection-protection-level="promptInjectionProtection"
        :show-protection="promptInjectionProtectionAvailable"
        @mcp-change="onDuoWorkflowMcpChanged"
        @protection-level-change="onPromptInjectionProtectionChanged"
      />
    </template>
  </ai-common-settings>
</template>
