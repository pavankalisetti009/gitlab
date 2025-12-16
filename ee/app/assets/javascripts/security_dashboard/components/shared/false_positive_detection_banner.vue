<script>
import { GlBanner, GlSprintf, GlLink } from '@gitlab/ui';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { s__ } from '~/locale';
import {
  DOC_PATH_VULNERABILITY_REPORT,
  DOC_PATH_SAST_FALSE_POSITIVE_DETECTION,
  DOC_PATH_DISMISSING_FALSE_POSITIVES,
} from 'ee/security_dashboard/constants';

export default {
  name: 'FalsePositiveDetectionBanner',
  components: {
    GlBanner,
    GlSprintf,
    GlLink,
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
        'SecurityReports|GitLab Duo will automatically review new critical and high severity %{linkStart}SAST vulnerabilities on the default branch to identify potential false positives%{linkEnd}. GitLab Duo assigns each false positive a confidence score and %{dismissLinkStart}you can bulk dismiss the identified false positives%{dismissLinkEnd} in the vulnerability report. The service is a free beta for a limited time and is disabled by default. You can turn on this feature in the GitLab Duo settings.',
      ),
    },
  },
  DOC_PATH_SAST_FALSE_POSITIVE_DETECTION,
  DOC_PATH_DISMISSING_FALSE_POSITIVES,
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
        <p>
          <gl-sprintf :message="$options.i18n.fpDetectionBanner.content">
            <template #link="{ content }">
              <gl-link :href="$options.DOC_PATH_SAST_FALSE_POSITIVE_DETECTION" target="_blank">{{
                content
              }}</gl-link>
            </template>
            <template #dismissLink="{ content }">
              <gl-link :href="$options.DOC_PATH_DISMISSING_FALSE_POSITIVES" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
        </p>
      </gl-banner>
    </template>
  </user-callout-dismisser>
</template>
