<script>
import { GlBanner, GlLink, GlSprintf } from '@gitlab/ui';
import shieldCheckIllustrationUrl from '@gitlab/svgs/dist/illustrations/secure-sm.svg?url';
import { helpPagePath } from '~/helpers/help_page_helper';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { s__ } from '~/locale';

export default {
  EXPERIMENTAL_FEATURES_PATH: helpPagePath(
    'user/application_security/policies/scan_execution_policies',
    {
      anchor: 'experimental-features',
    },
  ),
  SHARE_FEEDBACK_ATTRIBUTES: { target: '_blank' },
  SHARE_FEEDBACK_URL: 'https://gitlab.com/gitlab-org/gitlab/-/issues/434425',
  BANNER_STORAGE_KEY: 'security_policies_experimental_features',
  SVG_PATH: shieldCheckIllustrationUrl,
  name: 'ExperimentFeaturesBanner',
  components: {
    GlBanner,
    GlLink,
    GlSprintf,
    LocalStorageSync,
  },
  i18n: {
    buttonBannerText: s__('SecurityOrchestration|Share feedback'),
    bannerTitle: s__(
      'SecurityOrchestration|Introducing Pipeline Execution Policy Action experimental feature',
    ),
    bannerDescription: s__(
      'SecurityOrchestration|Enforce custom CI with pipeline execution action for scan execution policies. %{linkStart}How do I implement this feature?%{linkEnd}',
    ),
  },
  data() {
    return {
      feedbackBannerDismissed: false,
    };
  },
  methods: {
    dismissBanner() {
      this.feedbackBannerDismissed = true;
    },
  },
};
</script>

<template>
  <local-storage-sync v-model="feedbackBannerDismissed" :storage-key="$options.BANNER_STORAGE_KEY">
    <gl-banner
      v-if="!feedbackBannerDismissed"
      :button-attributes="$options.SHARE_FEEDBACK_ATTRIBUTES"
      :button-link="$options.SHARE_FEEDBACK_URL"
      :button-text="$options.i18n.buttonBannerText"
      :title="$options.i18n.bannerTitle"
      :svg-path="$options.SVG_PATH"
      @close="dismissBanner"
    >
      <p>
        <gl-sprintf :message="$options.i18n.bannerDescription">
          <template #link="{ content }">
            <gl-link :href="$options.EXPERIMENTAL_FEATURES_PATH" target="_blank">
              <p class="gl-mb-0">{{ content }}</p>
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
    </gl-banner>
  </local-storage-sync>
</template>
>
