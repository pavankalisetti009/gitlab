<script>
import { GlExperimentBadge } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import EdgeCasesSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/edge_cases_section.vue';
import FallbackSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/fallback_section.vue';
import DimDisableContainer from '../../dim_disable_container.vue';
import { CLOSED } from './constants';

export default {
  i18n: {
    title: s__('ScanResultPolicy|Fallback behavior and edge case settings'),
    fallbackBehaviorTitle: s__('ScanResultPolicy|Fallback behavior'),
    edgeCaseSettingsTitle: s__('ScanResultPolicy|Edge case settings'),
    experimentTitle: __('Experiment'),
  },
  components: {
    FallbackSection,
    EdgeCasesSection,
    DimDisableContainer,
    GlExperimentBadge,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    policy: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  computed: {
    fallbackBehaviorSetting() {
      return this.policy.fallback_behavior?.fail || CLOSED;
    },
  },
  methods: {
    updateProperty(key, value) {
      this.$emit('changed', key, value);
    },
  },
  POPOVER_TARGET_SELECTOR: 'fallback-popover',
};
</script>

<template>
  <div>
    <dim-disable-container :disabled="disabled">
      <template #title>
        <h4>{{ $options.i18n.title }}</h4>
      </template>

      <template #disabled>
        <div class="rounded gl-bg-subtle gl-p-6"></div>
      </template>

      <h5>{{ $options.i18n.fallbackBehaviorTitle }}</h5>
      <fallback-section :property="fallbackBehaviorSetting" @changed="updateProperty" />

      <h5>
        {{ $options.i18n.edgeCaseSettingsTitle }}
        <gl-experiment-badge class="gl-ml-2" />
      </h5>
      <edge-cases-section :policy-tuning="policy.policy_tuning" @changed="updateProperty" />
    </dim-disable-container>
  </div>
</template>
