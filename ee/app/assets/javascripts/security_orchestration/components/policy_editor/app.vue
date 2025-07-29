<script>
import { s__ } from '~/locale';
import { getParameterByName } from '~/lib/utils/url_utility';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { saveStorageValue } from '~/lib/utils/local_storage';
import AdvancedEditorToggle from 'ee/security_orchestration/components/policy_editor/advanced_editor_toggle.vue';
import AdvancedEditorBanner from 'ee/security_orchestration/components/policy_editor/advanced_editor_banner.vue';
import EditorWrapper from './editor_wrapper.vue';
import PolicyTypeSelector from './policy_type_selector.vue';
import { ADVANCED_EDITOR_STORAGE_KEY } from './constants';
import { getAdvancedEditorValue } from './utils';

export default {
  components: {
    AdvancedEditorBanner,
    AdvancedEditorToggle,
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
      advancedEditorEnabled: getAdvancedEditorValue(),
    };
  },
  computed: {
    hasNewSplitView() {
      return this.glFeatures.securityPoliciesSplitView;
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
    enableAdvancedEditor(value) {
      saveStorageValue(ADVANCED_EDITOR_STORAGE_KEY, value);
      this.advancedEditorEnabled = value;
    },
    policyFromUrl() {
      const policyType = getParameterByName('type');

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
    <advanced-editor-banner
      v-if="hasNewSplitView"
      class="gl-mt-4"
      @enable-advanced-editor="enableAdvancedEditor(true)"
    />
    <page-heading :heading="title">
      <template #actions>
        <advanced-editor-toggle
          v-if="hasNewSplitView"
          :advanced-editor-enabled="advancedEditorEnabled"
          @enable-advanced-editor="enableAdvancedEditor"
        />
      </template>
    </page-heading>
    <policy-type-selector v-if="!selectedPolicy" />
    <editor-wrapper
      v-else
      :advanced-editor-enabled="advancedEditorEnabled"
      :selected-policy="selectedPolicy"
    />
  </div>
</template>
