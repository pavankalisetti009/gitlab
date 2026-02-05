<script>
import { GlForm, GlAlert, GlButton } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { AVAILABILITY_OPTIONS } from '../constants';
import DuoAvailability from './duo_availability_form.vue';
import DuoExperimentBetaFeatures from './duo_experiment_beta_features_form.vue';
import DuoCoreFeaturesForm from './duo_core_features_form.vue';
import DuoPromptCache from './duo_prompt_cache_form.vue';
import DuoFlowSettings from './duo_flow_settings.vue';
import DuoFoundationalAgentsSettings from './duo_foundational_agents_settings.vue';
import DuoAgentPlatformSettingsForm from './duo_agent_platform_settings_form.vue';
import AiNamespaceAccessRules from './ai_namespace_access_rules.vue';
import AiRolePermissions from './ai_role_permissions.vue';

export default {
  name: 'AiCommonSettingsForm',
  components: {
    GlForm,
    GlAlert,
    GlButton,
    AiRolePermissions,
    DuoAvailability,
    DuoExperimentBetaFeatures,
    DuoCoreFeaturesForm,
    DuoPromptCache,
    DuoFlowSettings,
    DuoFoundationalAgentsSettings,
    DuoAgentPlatformSettingsForm,
    AiNamespaceAccessRules,
  },
  mixins: [glFeatureFlagMixin()],
  i18n: {
    defaultOffWarning: s__(
      'AiPowered|When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
    ),
    confirmButtonText: __('Save changes'),
    enabled: __('Enabled'),
    disabled: __('Disabled'),
  },
  inject: {
    onGeneralSettingsPage: { default: undefined },
    initialMinimumAccessLevelExecuteAsync: { default: undefined },
    initialMinimumAccessLevelExecuteSync: { default: undefined },
    showFoundationalAgentsAvailability: { default: undefined },
    isSaaS: { default: false },
  },
  props: {
    duoAvailability: {
      type: String,
      required: true,
    },
    duoAgentPlatformEnabled: {
      type: Boolean,
      required: true,
    },
    duoRemoteFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    duoFoundationalFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    experimentFeaturesEnabled: {
      type: Boolean,
      required: true,
    },
    duoCoreFeaturesEnabled: {
      type: Boolean,
      required: true,
      default: true,
    },
    promptCacheEnabled: {
      type: Boolean,
      required: true,
    },
    foundationalAgentsEnabled: {
      type: Boolean,
      required: true,
    },
    foundationalAgentsStatuses: {
      type: Array,
      required: true,
    },
    hasParentFormChanged: {
      type: Boolean,
      required: false,
      default: false,
    },
    selectedFoundationalFlowIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    duoWorkflowsDefaultImageRegistry: {
      type: String,
      required: false,
      default: '',
    },
    initialNamespaceAccessRules: {
      type: Array,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      availability: this.duoAvailability,
      flowEnabled: this.duoRemoteFlowsAvailability,
      experimentsEnabled: this.experimentFeaturesEnabled,
      duoCoreEnabled: this.duoCoreFeaturesEnabled,
      cacheEnabled: this.promptCacheEnabled,
      foundationalFlowsEnabled: this.duoFoundationalFlowsAvailability,
      foundationalAgentsEnabledInput: this.foundationalAgentsEnabled,
      foundationalAgentsStatusesInput: this.foundationalAgentsStatuses,
      duoAgentPlatformEnabledInput: this.duoAgentPlatformEnabled,
      hasFoundationalAgentsStatusesChanged: false,
      localSelectedFlowIds: this.selectedFoundationalFlowIds,
      localDefaultImageRegistry: this.duoWorkflowsDefaultImageRegistry,
      namespaceAccessRules: this.initialNamespaceAccessRules,
      minimumAccessLevelExecuteAsync: this.initialMinimumAccessLevelExecuteAsync,
      minimumAccessLevelExecuteSync: this.initialMinimumAccessLevelExecuteSync,
    };
  },
  computed: {
    hasAvailabilityChanged() {
      return this.availability !== this.duoAvailability;
    },
    hasExperimentCheckboxChanged() {
      return this.experimentsEnabled !== this.experimentFeaturesEnabled;
    },
    hasDuoCoreCheckboxChanged() {
      return this.duoCoreEnabled !== this.duoCoreFeaturesEnabled;
    },
    hasCacheCheckboxChanged() {
      return this.cacheEnabled !== this.promptCacheEnabled;
    },
    hasFlowFormChanged() {
      return this.flowEnabled !== this.duoRemoteFlowsAvailability;
    },
    hasFoundationalFlowsFormChanged() {
      return this.foundationalFlowsEnabled !== this.duoFoundationalFlowsAvailability;
    },

    hasFoundationalAgentsEnabledChanged() {
      return this.foundationalAgentsEnabled !== this.foundationalAgentsEnabledInput;
    },
    hasDuoAgentPlatformEnabledChanged() {
      return this.duoAgentPlatformEnabledInput !== this.duoAgentPlatformEnabled;
    },
    hasNamespaceAccessRulesChanged() {
      const currentLength = this.namespaceAccessRules?.length || 0;
      const initialLength = this.initialNamespaceAccessRules?.length || 0;

      if (currentLength !== initialLength) {
        return true;
      }

      return this.namespaceAccessRules?.some((namespaceAccessRule) => {
        const initialNamespaceAccessRule = this.initialNamespaceAccessRules.find(
          (rule) => rule.throughNamespace.id === namespaceAccessRule.throughNamespace.id,
        );

        if (!initialNamespaceAccessRule) return true;

        const currentFeatures = [...namespaceAccessRule.features].sort();
        const initialFeatures = [...initialNamespaceAccessRule.features].sort();

        return JSON.stringify(currentFeatures) !== JSON.stringify(initialFeatures);
      });
    },
    hasMinimumAccessLevelExecuteAsyncChanged() {
      return this.minimumAccessLevelExecuteAsync !== this.initialMinimumAccessLevelExecuteAsync;
    },
    hasMinimumAccessLevelExecuteSyncChanged() {
      return this.minimumAccessLevelExecuteSync !== this.initialMinimumAccessLevelExecuteSync;
    },
    hasMinimumAccessLevelExecuteChanged() {
      return (
        this.hasMinimumAccessLevelExecuteAsyncChanged ||
        this.hasMinimumAccessLevelExecuteSyncChanged
      );
    },
    hasDefaultImageRegistryChanged() {
      return this.localDefaultImageRegistry !== this.duoWorkflowsDefaultImageRegistry;
    },
    hasFormChanged() {
      return (
        this.hasAvailabilityChanged ||
        this.hasExperimentCheckboxChanged ||
        this.hasDuoCoreCheckboxChanged ||
        this.hasCacheCheckboxChanged ||
        this.hasParentFormChanged ||
        this.hasFlowFormChanged ||
        this.hasFoundationalFlowsFormChanged ||
        this.hasFoundationalAgentsEnabledChanged ||
        this.hasFoundationalAgentsStatusesChanged ||
        this.hasSelectedFlowIdsChanged ||
        this.hasDefaultImageRegistryChanged ||
        this.hasDuoAgentPlatformEnabledChanged ||
        this.hasNamespaceAccessRulesChanged ||
        this.hasMinimumAccessLevelExecuteChanged
      );
    },
    showWarning() {
      return this.hasAvailabilityChanged && this.warningAvailability;
    },
    warningAvailability() {
      return (
        this.availability === AVAILABILITY_OPTIONS.NEVER_ON ||
        this.availability === AVAILABILITY_OPTIONS.DEFAULT_OFF
      );
    },
    warningMessage() {
      const optsWithWarning = [AVAILABILITY_OPTIONS.DEFAULT_OFF, AVAILABILITY_OPTIONS.NEVER_ON];
      return optsWithWarning.includes(this.availability)
        ? this.$options.i18n.defaultOffWarning
        : '';
    },
    disableConfigCheckboxes() {
      return this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
    },
    hasSelectedFlowIdsChanged() {
      const current = (this.localSelectedFlowIds || []).slice().sort();
      const initial = (this.selectedFoundationalFlowIds || []).slice().sort();

      return JSON.stringify(current) !== JSON.stringify(initial);
    },
    shouldShowAiRolePermissionsForGroup() {
      return this.isSaaS && this.glFeatures.dapGroupCustomizablePermissions;
    },
    shouldShowAiRolePermissionsForInstance() {
      return !this.isSaaS && this.glFeatures.dapInstanceCustomizablePermissions;
    },
    shouldShowAiRolePermissions() {
      return (
        (this.shouldShowAiRolePermissionsForGroup || this.shouldShowAiRolePermissionsForInstance) &&
        !this.onGeneralSettingsPage
      );
    },
  },
  methods: {
    submitForm() {
      this.$emit('submit');
    },
    onMinimumAccessLevelExecuteAsyncChange(role) {
      this.minimumAccessLevelExecuteAsync = role;
      this.$emit('minimum-access-level-execute-async-changed', role);
    },
    onMinimumAccessLevelExecuteSyncChange(role) {
      this.minimumAccessLevelExecuteSync = role;
      this.$emit('minimum-access-level-execute-sync-changed', role);
    },
    onRadioChanged(value) {
      this.availability = value;
      this.$emit('radio-changed', value);
    },
    experimentCheckboxChanged(value) {
      this.experimentsEnabled = value;
      this.$emit('experiment-checkbox-changed', value);
    },
    duoCoreCheckboxChanged(value) {
      this.duoCoreEnabled = value;
      this.$emit('duo-core-checkbox-changed', value);
    },
    onCacheCheckboxChanged(value) {
      this.cacheEnabled = value;
      this.$emit('cache-checkbox-changed', value);
    },
    onFlowCheckboxChanged(value) {
      this.flowEnabled = value;
      this.$emit('duo-flow-checkbox-changed', value);
    },
    onFoundationalFlowsCheckboxChanged(value) {
      this.foundationalFlowsEnabled = value;
      this.$emit('duo-foundational-flows-checkbox-changed', value);
    },
    onFoundationalAgentsEnabledChanged(value) {
      this.foundationalAgentsEnabledInput = value;
      this.$emit('duo-foundational-agents-changed', value);
    },
    onFoundationalAgentsToggled(agentStatuses) {
      this.foundationalAgentsStatusesInput = agentStatuses;
      this.hasFoundationalAgentsStatusesChanged = true;
      this.$emit('duo-foundational-agents-statuses-change', agentStatuses);
    },
    onSelectedFlowIdsChanged(flowIds) {
      this.localSelectedFlowIds = flowIds;
      this.$emit('change-selected-flow-ids', flowIds);
    },
    onDefaultImageRegistryChanged(value) {
      this.localDefaultImageRegistry = value;
      this.$emit('change-default-image-registry', value);
    },
    onDuoAgentPlatformEnabledChanged(value) {
      this.duoAgentPlatformEnabledInput = value;
      this.$emit('duo-agent-platform-enabled-changed', value);
    },
    onNamespaceAccessRulesChanged(value) {
      this.namespaceAccessRules = value;
      this.$emit('namespace-access-rules-changed', value);
    },
  },
};
</script>

<template>
  <gl-form @submit.prevent="submitForm">
    <slot name="ai-common-settings-top"></slot>
    <duo-availability :duo-availability="availability" @change="onRadioChanged" />

    <ai-namespace-access-rules
      v-if="initialNamespaceAccessRules && !onGeneralSettingsPage"
      :initial-namespace-access-rules="namespaceAccessRules"
      @change="onNamespaceAccessRulesChanged"
    />

    <duo-core-features-form
      v-if="!onGeneralSettingsPage"
      :duo-core-features-enabled="duoCoreEnabled"
      :disabled-checkbox="disableConfigCheckboxes"
      @change="duoCoreCheckboxChanged"
    />

    <duo-experiment-beta-features
      :experiment-features-enabled="experimentsEnabled"
      :disabled-checkbox="disableConfigCheckboxes"
      @change="experimentCheckboxChanged"
    />

    <duo-agent-platform-settings-form
      :enabled="duoAgentPlatformEnabledInput"
      @selected="onDuoAgentPlatformEnabledChanged"
    >
      <duo-flow-settings
        :duo-remote-flows-availability="duoRemoteFlowsAvailability"
        :duo-foundational-flows-availability="duoFoundationalFlowsAvailability"
        :duo-workflows-default-image-registry="duoWorkflowsDefaultImageRegistry"
        :disabled-checkbox="disableConfigCheckboxes"
        :selected-foundational-flow-ids="localSelectedFlowIds"
        @change="onFlowCheckboxChanged"
        @change-foundational-flows="onFoundationalFlowsCheckboxChanged"
        @change-selected-flow-ids="onSelectedFlowIdsChanged"
        @change-default-image-registry="onDefaultImageRegistryChanged"
      />
      <duo-foundational-agents-settings
        v-if="showFoundationalAgentsAvailability"
        :enabled="foundationalAgentsEnabledInput"
        :agent-statuses="foundationalAgentsStatusesInput"
        @change="onFoundationalAgentsEnabledChanged"
        @agent-toggle="onFoundationalAgentsToggled"
      />
    </duo-agent-platform-settings-form>

    <duo-prompt-cache
      :prompt-cache-enabled="cacheEnabled"
      :disabled-checkbox="disableConfigCheckboxes"
      class="gl-mb-4"
      @change="onCacheCheckboxChanged"
    />

    <ai-role-permissions
      v-if="shouldShowAiRolePermissions"
      :initial-minimum-access-level-execute-async="minimumAccessLevelExecuteAsync"
      :initial-minimum-access-level-execute-sync="minimumAccessLevelExecuteSync"
      @minimum-access-level-execute-async-change="onMinimumAccessLevelExecuteAsyncChange"
      @minimum-access-level-execute-sync-change="onMinimumAccessLevelExecuteSyncChange"
    />

    <slot name="ai-common-settings-bottom"></slot>
    <gl-alert
      v-if="showWarning"
      :dismissible="false"
      variant="warning"
      data-testid="duo-settings-show-warning-alert"
    >
      {{ warningMessage }}
    </gl-alert>
    <gl-button class="gl-mt-6" type="submit" variant="confirm" :disabled="!hasFormChanged">
      {{ $options.i18n.confirmButtonText }}
    </gl-button>
  </gl-form>
</template>
