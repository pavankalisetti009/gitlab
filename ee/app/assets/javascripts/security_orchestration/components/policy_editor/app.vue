<script>
import { s__ } from '~/locale';
import { getParameterByName } from '~/lib/utils/url_utility';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AdvancedEditorToggle from 'ee/security_orchestration/components/policy_editor/advanced_editor_toggle.vue';
import AutoDismissedActionBanner from 'ee/security_orchestration/components/policy_editor/auto_dismissed_action_banner.vue';
import AdvancedEditorBanner from 'ee/security_orchestration/components/policy_editor/advanced_editor_banner.vue';
import EditorWrapper from './editor_wrapper.vue';
import PolicyTypeSelector from './policy_type_selector.vue';

export default {
  components: {
    AdvancedEditorBanner,
    AdvancedEditorToggle,
    AutoDismissedActionBanner,
    EditorWrapper,
    PolicyTypeSelector,
    PageHeading,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    existingPolicy: { default: null },
  },
  data() {
    return {
      selectedPolicy: this.policyFromUrl(),
      hasPolicyType: false,
    };
  },
  computed: {
    hasNewSplitView() {
      return this.glFeatures.securityPoliciesSplitView && this.hasPolicyType;
    },
    hasAutoDismissVulnerabilityPolicies() {
      return this.glFeatures.autoDismissVulnerabilityPolicies && this.isVulnerabilityType;
    },
    isVulnerabilityType() {
      return this.selectedPolicy?.urlParameter === 'vulnerability_management_policy';
    },
    title() {
      const titleType = this.existingPolicy
        ? this.$options.i18n.editTitles
        : this.$options.i18n.titles;

      return titleType[this.selectedPolicy?.value] || titleType.default;
    },
  },
  created() {
    this.policyFromUrl(getParameterByName('type'));
  },
  methods: {
    policyFromUrl() {
      const policyType = getParameterByName('type');
      this.hasPolicyType = Boolean(policyType);

      return Object.values(POLICY_TYPE_COMPONENT_OPTIONS).find(
        ({ urlParameter }) => urlParameter === policyType,
      );
    },
  },
  i18n: {
    titles: {
      [POLICY_TYPE_COMPONENT_OPTIONS.approval.value]: s__(
        'SecurityOrchestration|New merge request approval policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value]: s__(
        'SecurityOrchestration|New scan execution policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.value]: s__(
        'SecurityOrchestration|New pipeline execution policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.value]: s__(
        'SecurityOrchestration|New vulnerability management policy',
      ),
      default: s__('SecurityOrchestration|New policy'),
    },
    editTitles: {
      [POLICY_TYPE_COMPONENT_OPTIONS.approval.value]: s__(
        'SecurityOrchestration|Edit merge request approval policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value]: s__(
        'SecurityOrchestration|Edit scan execution policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.value]: s__(
        'SecurityOrchestration|Edit pipeline execution policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.value]: s__(
        'SecurityOrchestration|Edit vulnerability management policy',
      ),
      default: s__('SecurityOrchestration|Edit policy'),
    },
  },
};
</script>
<template>
  <div>
    <advanced-editor-banner v-if="hasNewSplitView" class="gl-mt-4" />

    <auto-dismissed-action-banner v-if="hasAutoDismissVulnerabilityPolicies" class="gl-mt-4" />

    <page-heading :heading="title">
      <template #actions>
        <advanced-editor-toggle v-if="hasNewSplitView" />
      </template>
    </page-heading>
    <policy-type-selector v-if="!selectedPolicy" />
    <editor-wrapper v-else :selected-policy="selectedPolicy" />
  </div>
</template>
