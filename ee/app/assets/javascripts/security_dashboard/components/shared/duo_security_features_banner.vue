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
  name: 'DuoSecurityFeaturesBanner',
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
    shouldShowSecurityFeaturesBanner() {
      return this.glFeatures?.agenticSastVrUi;
    },
    shouldShowManageButton() {
      return this.canAdminVulnerability && this.manageDuoSettingsPath;
    },
    securityFeaturesBannerButtonText() {
      return this.$options.i18n.securityFeaturesBanner[
        this.shouldShowManageButton ? 'buttonText' : 'buttonTextAlt'
      ];
    },
    securityFeaturesBannerButtonLink() {
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
      content: s__(
        'SecurityReports|GitLab Duo can automatically review new critical and high severity SAST vulnerabilities on the default branch to %{linkStart}identify potential false positives%{linkEnd}. GitLab Duo can assign each false positive a confidence score and %{dismissLinkStart}you can bulk dismiss the identified false positives%{dismissLinkEnd} in the vulnerability report. The feature is available as a free beta for a limited time and is disabled by default. You can turn on this feature in the GitLab Duo settings.',
      ),
    },
    securityFeaturesBanner: {
      title: s__('SecurityReports|GitLab Duo security features are here!'),
      buttonText: s__('SecurityReports|Manage settings'),
      buttonTextAlt: s__('SecurityReports|Learn more'),
      content: s__(
        'SecurityReports|GitLab Duo can automatically scan security findings to %{fpLinkStart}identify false positives%{fpLinkEnd} and %{vrLinkStart}generate fixes for vulnerabilities%{vrLinkEnd}. GitLab Duo can assign each finding a GitLab Duo confidence score. You can adjust or disable these features in the GitLab Duo Settings.',
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
    <template v-if="shouldShowSecurityFeaturesBanner" #default="{ dismiss, shouldShowCallout }">
      <gl-banner
        v-if="shouldShowCallout"
        class="gl-mt-5"
        :title="$options.i18n.securityFeaturesBanner.title"
        :button-text="securityFeaturesBannerButtonText"
        :button-link="securityFeaturesBannerButtonLink"
        variant="introduction"
        @close="dismiss"
      >
        <p>
          <gl-sprintf :message="$options.i18n.securityFeaturesBanner.content">
            <template #fpLink="{ content }">
              <gl-link :href="$options.DOC_PATH_SAST_FALSE_POSITIVE_DETECTION" target="_blank">{{
                content
              }}</gl-link>
            </template>
            <template #vrLink="{ content }">
              <gl-link :href="$options.DOC_PATH_DISMISSING_FALSE_POSITIVES" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
        </p>
      </gl-banner>
    </template>
    <template v-else #default="{ dismiss, shouldShowCallout }">
      <gl-banner
        v-if="shouldShowCallout"
        class="gl-mt-5"
        :title="$options.i18n.fpDetectionBanner.title"
        :button-text="securityFeaturesBannerButtonText"
        :button-link="securityFeaturesBannerButtonLink"
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
