<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCommonSettingsForm from './ai_common_settings_form.vue';

export default {
  name: 'AiCommonSettings',
  components: {
    GlLink,
    GlSprintf,
    SettingsBlock,
    AiCommonSettingsForm,
    PageHeading,
  },
  i18n: {
    confirmButtonText: __('Save changes'),
    settingsBlockTitle: __('GitLab Duo features'),
    settingsBlockDescription: s__(
      'AiPowered|Configure AI-native GitLab Duo features. %{linkStart}Which features?%{linkEnd}',
    ),
    configurationPageTitle: s__('AiPowered|Configuration'),
  },
  inject: [
    'duoAvailability',
    'experimentFeaturesEnabled',
    'duoCoreFeaturesEnabled',
    'onGeneralSettingsPage',
    'promptCacheEnabled',
    'initialDuoRemoteFlowsAvailability',
    'initialDuoFoundationalFlowsAvailability',
    'initialDuoWorkflowsDefaultImageRegistry',
    'foundationalAgentsDefaultEnabled',
    'initialFoundationalAgentsStatuses',
    'initialSelectedFoundationalFlowIds',
    'initialDuoAgentPlatformEnabled',
    'initialNamespaceAccessRules',
    'initialMinimumAccessLevelExecuteAsync',
    'initialMinimumAccessLevelExecuteSync',
  ],
  props: {
    hasParentFormChanged: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      availability: this.duoAvailability,
      experimentsEnabled: this.experimentFeaturesEnabled,
      duoCoreEnabled: this.duoCoreFeaturesEnabled,
      cacheEnabled: this.promptCacheEnabled,
      duoRemoteFlowsAvailability: this.initialDuoRemoteFlowsAvailability,
      duoFoundationalFlowsAvailability: this.initialDuoFoundationalFlowsAvailability,
      duoWorkflowsDefaultImageRegistry: this.initialDuoWorkflowsDefaultImageRegistry,
      foundationalAgentsEnabled: this.foundationalAgentsDefaultEnabled,
      selectedFlowIds: this.initialSelectedFoundationalFlowIds || [],
      foundationalAgentsStatuses: this.initialFoundationalAgentsStatuses,
      duoAgentPlatformEnabled: this.initialDuoAgentPlatformEnabled,
      namespaceAccessRulesChanged: false,
      namespaceAccessRules: this.initialNamespaceAccessRules,
      minimumAccessLevelExecuteAsync: this.initialMinimumAccessLevelExecuteAsync,
      minimumAccessLevelExecuteSync: this.initialMinimumAccessLevelExecuteSync,
    };
  },
  methods: {
    submitForm() {
      const payload = {
        duoAvailability: this.availability,
        experimentFeaturesEnabled: this.experimentsEnabled,
        duoCoreFeaturesEnabled: this.duoCoreEnabled,
        promptCacheEnabled: this.cacheEnabled,
        duoRemoteFlowsAvailability: this.duoRemoteFlowsAvailability,
        duoFoundationalFlowsAvailability: this.duoFoundationalFlowsAvailability,
        duoWorkflowsDefaultImageRegistry: this.duoWorkflowsDefaultImageRegistry,
        foundationalAgentsEnabled: this.foundationalAgentsEnabled,
        foundationalAgentsStatuses: this.foundationalAgentsStatuses,
        selectedFoundationalFlowIds: this.selectedFlowIds,
        duoAgentPlatformEnabled: this.duoAgentPlatformEnabled,
        minimumAccessLevelExecuteAsync: this.minimumAccessLevelExecuteAsync,
        minimumAccessLevelExecuteSync: this.minimumAccessLevelExecuteSync,
      };

      if (this.namespaceAccessRulesChanged) {
        payload.namespaceAccessRules = this.namespaceAccessRules;
      }

      this.$emit('submit', payload);
    },
    onRadioChanged(value) {
      this.availability = value;
    },
    experimentCheckboxChanged(value) {
      this.experimentsEnabled = value;
    },
    duoCoreCheckboxChanged(value) {
      this.duoCoreEnabled = value;
    },
    onCacheCheckboxChanged(value) {
      this.cacheEnabled = value;
    },
    onDuoFlowChanged(value) {
      this.duoRemoteFlowsAvailability = value;
    },
    onDuoFoundationalFlowsChanged(value) {
      this.duoFoundationalFlowsAvailability = value;
    },
    onFoundationalAgentsEnabledChanged(value) {
      this.foundationalAgentsEnabled = value;
    },
    onDuoAgentPlatformEnabledChanged(value) {
      this.duoAgentPlatformEnabled = value;
    },
    onFoundationalAgentsStatusesChanged(agentStatuses) {
      this.foundationalAgentsStatuses = agentStatuses;
    },
    onSelectedFlowIdsChanged(flowIds) {
      this.selectedFlowIds = flowIds;
    },
    onDefaultImageRegistryChanged(value) {
      this.duoWorkflowsDefaultImageRegistry = value;
    },
    onNamespaceAccessRulesChanged(rules) {
      this.namespaceAccessRulesChanged = true;
      this.namespaceAccessRules = rules;
    },
    onMinimumAccessLevelExecuteAsyncChanged(value) {
      this.minimumAccessLevelExecuteAsync = value;
    },
    onMinimumAccessLevelExecuteSyncChanged(value) {
      this.minimumAccessLevelExecuteSync = value;
    },
  },
  aiFeaturesHelpPath: helpPagePath('user/gitlab_duo/_index'),
};
</script>
<template>
  <div>
    <template v-if="onGeneralSettingsPage">
      <settings-block
        id="js-gitlab-duo-settings"
        class="gl-mb-5 !gl-pt-5"
        :title="$options.i18n.settingsBlockTitle"
      >
        <template #description>
          <gl-sprintf
            data-testid="general-settings-subtitle"
            :message="
              s__(
                'AiPowered|Configure AI-native GitLab Duo features. %{linkStart}Which features?%{linkEnd}',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.aiFeaturesHelpPath">{{ content }} </gl-link>
            </template>
          </gl-sprintf>
        </template>
        <template #default>
          <ai-common-settings-form
            :duo-availability="duoAvailability"
            :duo-remote-flows-availability="initialDuoRemoteFlowsAvailability"
            :duo-foundational-flows-availability="initialDuoFoundationalFlowsAvailability"
            :duo-workflows-default-image-registry="initialDuoWorkflowsDefaultImageRegistry"
            :selected-foundational-flow-ids="initialSelectedFoundationalFlowIds"
            :experiment-features-enabled="experimentFeaturesEnabled"
            :duo-core-features-enabled="duoCoreFeaturesEnabled"
            :prompt-cache-enabled="promptCacheEnabled"
            :has-parent-form-changed="hasParentFormChanged"
            :duo-agent-platform-enabled="initialDuoAgentPlatformEnabled"
            :foundational-agents-enabled="foundationalAgentsDefaultEnabled"
            :foundational-agents-statuses="foundationalAgentsStatuses"
            @submit="submitForm"
            @radio-changed="onRadioChanged"
            @experiment-checkbox-changed="experimentCheckboxChanged"
            @duo-core-checkbox-changed="duoCoreCheckboxChanged"
            @cache-checkbox-changed="onCacheCheckboxChanged"
            @duo-flow-checkbox-changed="onDuoFlowChanged"
            @duo-agent-platform-enabled-changed="onDuoAgentPlatformEnabledChanged"
            @duo-foundational-agents-changed="onFoundationalAgentsEnabledChanged"
            @duo-foundational-agents-statuses-change="onFoundationalAgentsStatusesChanged"
            @duo-foundational-flows-checkbox-changed="onDuoFoundationalFlowsChanged"
            @change-selected-flow-ids="onSelectedFlowIdsChanged"
            @change-default-image-registry="onDefaultImageRegistryChanged"
          >
            <template #ai-common-settings-top>
              <slot name="ai-common-settings-top"></slot>
            </template>
            <template #ai-common-settings-bottom>
              <slot name="ai-common-settings-bottom"></slot>
            </template>
          </ai-common-settings-form>
        </template>
      </settings-block>
    </template>
    <template v-else>
      <page-heading :heading="$options.i18n.configurationPageTitle">
        <template #description>
          <span data-testid="configuration-page-subtitle">
            <gl-sprintf :message="$options.i18n.settingsBlockDescription">
              <template #link="{ content }">
                <gl-link :href="$options.aiFeaturesHelpPath">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </span>
        </template>
      </page-heading>
      <ai-common-settings-form
        :duo-availability="duoAvailability"
        :duo-remote-flows-availability="initialDuoRemoteFlowsAvailability"
        :duo-foundational-flows-availability="initialDuoFoundationalFlowsAvailability"
        :duo-workflows-default-image-registry="initialDuoWorkflowsDefaultImageRegistry"
        :selected-foundational-flow-ids="initialSelectedFoundationalFlowIds"
        :experiment-features-enabled="experimentFeaturesEnabled"
        :duo-core-features-enabled="duoCoreFeaturesEnabled"
        :prompt-cache-enabled="promptCacheEnabled"
        :has-parent-form-changed="hasParentFormChanged"
        :duo-agent-platform-enabled="initialDuoAgentPlatformEnabled"
        :foundational-agents-enabled="foundationalAgentsDefaultEnabled"
        :foundational-agents-statuses="foundationalAgentsStatuses"
        :initial-namespace-access-rules="initialNamespaceAccessRules"
        @submit="submitForm"
        @radio-changed="onRadioChanged"
        @experiment-checkbox-changed="experimentCheckboxChanged"
        @duo-core-checkbox-changed="duoCoreCheckboxChanged"
        @cache-checkbox-changed="onCacheCheckboxChanged"
        @duo-flow-checkbox-changed="onDuoFlowChanged"
        @duo-foundational-flows-checkbox-changed="onDuoFoundationalFlowsChanged"
        @duo-agent-platform-enabled-changed="onDuoAgentPlatformEnabledChanged"
        @duo-foundational-agents-changed="onFoundationalAgentsEnabledChanged"
        @duo-foundational-agents-statuses-change="onFoundationalAgentsStatusesChanged"
        @change-selected-flow-ids="onSelectedFlowIdsChanged"
        @change-default-image-registry="onDefaultImageRegistryChanged"
        @namespace-access-rules-changed="onNamespaceAccessRulesChanged"
        @minimum-access-level-execute-async-changed="onMinimumAccessLevelExecuteAsyncChanged"
        @minimum-access-level-execute-sync-changed="onMinimumAccessLevelExecuteSyncChanged"
      >
        <template #ai-common-settings-top>
          <slot name="ai-common-settings-top"></slot>
        </template>
        <template #ai-common-settings-bottom>
          <slot name="ai-common-settings-bottom"></slot>
        </template>
      </ai-common-settings-form>
    </template>
  </div>
</template>
