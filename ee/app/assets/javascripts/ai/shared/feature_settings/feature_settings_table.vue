<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import FeatureSettingsTableRows from './feature_settings_table_rows.vue';
import { DUO_MAIN_FEATURES } from './constants';

export default {
  name: 'FeatureSettingsTable',
  components: {
    FeatureSettingsTableRows,
    GlLink,
    GlSprintf,
  },
  props: {
    featureSettings: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  codeSuggestionsHelpPage: helpPagePath('user/project/repository/code_suggestions/_index'),
  duoChatHelpPage: helpPagePath('user/gitlab_duo_chat/_index'),
  otherGitLabDuoHelpPage: helpPagePath('user/get_started/getting_started_gitlab_duo', {
    anchor: 'step-3-try-other-gitlab-duo-features',
  }),
  computed: {
    codeSuggestionsFeatures() {
      return this.getSubFeatures(DUO_MAIN_FEATURES.CODE_SUGGESTIONS);
    },
    duoChatFeatures() {
      return this.getSubFeatures(DUO_MAIN_FEATURES.DUO_CHAT);
    },
    otherGitLabDuoFeatures() {
      return this.getSubFeatures(DUO_MAIN_FEATURES.OTHER_GITLAB_DUO_FEATURES);
    },
  },
  methods: {
    getSubFeatures(mainFeature) {
      return this.featureSettings.filter((setting) => setting.mainFeature === mainFeature);
    },
  },
};
</script>
<template>
  <div>
    <div class="gl-p-5">
      <h2 class="gl-heading-2 gl-mb-2">{{ s__('AdminAIPoweredFeatures|Code Suggestions') }}</h2>
      <p class="gl-mb-0 gl-text-subtle">
        <gl-sprintf
          :message="
            s__(
              'AdminAIPoweredFeatures|Assists developers by providing real-time code completions and recommendations. %{linkStart}Learn more.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.codeSuggestionsHelpPage" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </div>
    <feature-settings-table-rows
      data-testid="code-suggestions-table-rows"
      :ai-feature-settings="codeSuggestionsFeatures"
      :is-loading="isLoading"
    />
    <div class="gl-p-5 gl-pt-0 md:gl-p-5">
      <h2 class="gl-heading-2 gl-mb-2">{{ s__('AdminAIPoweredFeatures|GitLab Duo Chat') }}</h2>
      <p class="gl-mb-0 gl-text-subtle">
        <gl-sprintf
          :message="
            s__(
              'AdminAIPoweredFeatures|An AI assistant that provides real-time guidance helping users understand code, generate tests, and boost collaboration, using Chat. %{linkStart}Learn more.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.duoChatHelpPage" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </div>
    <feature-settings-table-rows
      data-testid="duo-chat-table-rows"
      :ai-feature-settings="duoChatFeatures"
      :is-loading="isLoading"
    />
    <div class="gl-p-5 gl-pt-0 md:gl-p-5">
      <h2 class="gl-heading-2 gl-mb-2">
        {{ s__('AdminAIPoweredFeatures|Other GitLab Duo features') }}
      </h2>
      <p class="gl-mb-0 gl-text-subtle">
        <gl-sprintf
          :message="
            s__(
              'AdminAIPoweredFeatures|An AI assistant that provides real-time guidance helping users accomplish tasks like generate commit messages and merge request descriptions, without Chat. %{linkStart}Learn more.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.otherGitLabDuoHelpPage" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </div>
    <feature-settings-table-rows
      data-testid="other-duo-features-table-rows"
      :ai-feature-settings="otherGitLabDuoFeatures"
      :is-loading="isLoading"
    />
  </div>
</template>
