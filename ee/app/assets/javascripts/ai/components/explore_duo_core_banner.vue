<script>
import { GlBanner, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';

export default {
  name: 'ExploreDuoCoreBanner',
  i18n: {
    bannerBody: s__(
      'AiPowered|You now have access to GitLab Duo Chat and Code Suggestions in supported IDEs. To start using these features, %{link1Start}install the GitLab extension in your IDE%{link1End}. If you already have this extension installed, %{link2Start}explore what you can do with GitLab Duo Core%{link2End}.',
    ),
  },
  components: {
    GlBanner,
    GlLink,
    GlSprintf,
    UserCalloutDismisser,
  },
  props: {
    calloutFeatureName: {
      type: String,
      required: true,
      default: '',
    },
  },
  installExtensionLink: `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo/#step-4-prepare-to-use-gitlab-duo-in-your-ide`,
  exploreGitLabDuoLink: `${DOCS_URL_IN_EE_DIR}/user/gitlab_duo/#summary-of-gitlab-duo-features`,
  ctaLink: `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo/`,
};
</script>

<template>
  <div>
    <user-callout-dismisser :feature-name="calloutFeatureName">
      <template #default="{ dismiss, shouldShowCallout }">
        <gl-banner
          v-if="shouldShowCallout"
          :title="s__('AiPowered|Get started with GitLab Duo')"
          class="explore-duo-core-banner gl-mb-5 gl-mt-5"
          :button-text="s__('AiPowered|Explore GitLab Duo Core')"
          :button-link="$options.ctaLink"
          @primary="dismiss"
          @close="dismiss"
        >
          <p>
            <gl-sprintf :message="$options.i18n.bannerBody">
              <template #link1="{ content }">
                <gl-link :href="$options.installExtensionLink" target="_blank">
                  {{ content }}
                </gl-link>
              </template>
              <template #link2="{ content }">
                <gl-link :href="$options.exploreGitLabDuoLink" target="_blank">
                  {{ content }}
                </gl-link>
              </template>
            </gl-sprintf>
          </p>
        </gl-banner>
      </template>
    </user-callout-dismisser>
  </div>
</template>

<style scoped>
.explore-duo-core-banner {
  background-image: url('duo_banner_background.svg?url');
  background-size: cover;
  background-position: center;
  background-repeat: no-repeat;
}
</style>
