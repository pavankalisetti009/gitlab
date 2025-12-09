<script>
import { GlBanner } from '@gitlab/ui';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { s__ } from '~/locale';
import { DOC_PATH_VULNERABILITY_REPORT } from 'ee/security_dashboard/constants';

export default {
  name: 'FalsePositiveDetectionBanner',
  components: {
    GlBanner,
    UserCalloutDismisser,
  },
  mixins: [glFeatureFlagMixin()],
  inject: {
    canAdminVulnerability: {
      default: false,
    },
    manageDuoSettingsPath: {
      default: '',
    },
  },
  computed: {
    shouldShowFpDetectionBanner() {
      return this.glFeatures?.aiExperimentSastFpDetection;
    },
    shouldShowManageButton() {
      return this.canAdminVulnerability && this.manageDuoSettingsPath;
    },
    fpDetectionBannerButtonText() {
      return this.$options.i18n.fpDetectionBanner[
        this.shouldShowManageButton ? 'buttonText' : 'buttonTextAlt'
      ];
    },
    fpDetectionBannerButtonLink() {
      return this.shouldShowManageButton
        ? this.manageDuoSettingsPath
        : DOC_PATH_VULNERABILITY_REPORT;
    },
  },
  i18n: {
    fpDetectionBanner: {
      title: s__(
        'SecurityReports|GitLab Duo SAST false positive detection - available for a limited time in free Beta',
      ),
      buttonText: s__('SecurityReports|Manage settings'),
      buttonTextAlt: s__('SecurityReports|Learn more'),
      content: s__(
        'SecurityReports|GitLab Duo automatically reviews critical and high severity SAST vulnerabilities to identify potential false positives. GitLab Duo assigns each false positive a confidence score and you can bulk dismiss the identified false positives in the vulnerability report. The service is enabled by default for free during the beta. You can adjust or turn off this feature in the GitLab Duo settings.',
      ),
    },
  },
};
</script>
<template>
  <user-callout-dismisser
    v-if="shouldShowFpDetectionBanner"
    feature-name="ai_experiment_sast_fp_detection"
  >
    <template #default="{ dismiss, shouldShowCallout }">
      <gl-banner
        v-if="shouldShowCallout"
        class="gl-mt-5"
        :title="$options.i18n.fpDetectionBanner.title"
        :button-text="fpDetectionBannerButtonText"
        :button-link="fpDetectionBannerButtonLink"
        variant="introduction"
        @close="dismiss"
      >
        <p>{{ $options.i18n.fpDetectionBanner.content }}</p>
      </gl-banner>
    </template>
  </user-callout-dismisser>
</template>
