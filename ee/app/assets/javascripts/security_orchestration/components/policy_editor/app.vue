<script>
import { s__ } from '~/locale';
import { getParameterByName } from '~/lib/utils/url_utility';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import EditorWrapper from './editor_wrapper.vue';
import PolicyTypeSelector from './policy_type_selector.vue';

export default {
  components: {
    EditorWrapper,
    PolicyTypeSelector,
    PageHeading,
  },
  mixins: [glFeatureFlagMixin()],
  inject: {
    namespaceType: { default: '' },
    existingPolicy: { default: null },
  },
  data() {
    return {
      selectedPolicy: this.policyFromUrl(),
    };
  },
  computed: {
    title() {
      if (this.existingPolicy) {
        return (
          this.$options.i18n.editTitles[this.selectedPolicy?.value] ||
          this.$options.i18n.editTitles.fallBack
        );
      }

      return this.$options.i18n.titles.default;
    },
  },
  created() {
    this.policyFromUrl(getParameterByName('type'));
  },
  methods: {
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
      default: s__('SecurityOrchestration|New policy'),
    },
    editTitles: {
      [POLICY_TYPE_COMPONENT_OPTIONS.approval.value]: s__(
        'SecurityOrchestration|Edit merge request approval policy',
      ),
      [POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value]: s__(
        'SecurityOrchestration|Edit scan execution policy',
      ),
      fallBack: s__('SecurityOrchestration|Edit policy'),
    },
  },
};
</script>
<template>
  <div>
    <page-heading :heading="title" />
    <policy-type-selector v-if="!selectedPolicy" />
    <editor-wrapper v-else :selected-policy-type="selectedPolicy.value" />
  </div>
</template>
