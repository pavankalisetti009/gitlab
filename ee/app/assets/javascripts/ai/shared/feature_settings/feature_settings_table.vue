<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import FeatureSettingsTableRows from './feature_settings_table_rows.vue';
import FeatureSettingsBlock from './feature_settings_block.vue';
import { DUO_MAIN_FEATURES } from './constants';

export default {
  name: 'FeatureSettingsTable',
  components: {
    FeatureSettingsTableRows,
    FeatureSettingsBlock,
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
  mergeRequestsHelpPage: helpPagePath('user/project/merge_requests/duo_in_merge_requests'),
  issuesHelpPage: helpPagePath('user/discussions/_index', {
    anchor: 'summarize-issue-discussions-with-duo-chat',
  }),
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
    mergeRequestFeatures() {
      return this.getSubFeatures(DUO_MAIN_FEATURES.MERGE_REQUESTS);
    },
    issueFeatures() {
      return this.getSubFeatures(DUO_MAIN_FEATURES.ISSUES);
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
    <feature-settings-block
      id="code-suggestions"
      :title="s__('AdminAIPoweredFeatures|Code Suggestions')"
    >
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'AdminAIPoweredFeatures|Assists developers by generating and completing code in real-time. %{linkStart}Learn more.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.codeSuggestionsHelpPage" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
      <template #content>
        <feature-settings-table-rows
          data-testid="code-suggestions-table-rows"
          :ai-feature-settings="codeSuggestionsFeatures"
          :is-loading="isLoading"
        />
      </template>
    </feature-settings-block>
    <feature-settings-block id="duo-chat" :title="s__('AdminAIPoweredFeatures|GitLab Duo Chat')">
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'AdminAIPoweredFeatures|An AI assistant that helps users accelerate software development using real-time conversational AI. %{linkStart}Learn more.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.duoChatHelpPage" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
      <template #content>
        <feature-settings-table-rows
          data-testid="duo-chat-table-rows"
          :ai-feature-settings="duoChatFeatures"
          :is-loading="isLoading"
        />
      </template>
    </feature-settings-block>
    <feature-settings-block
      id="duo-merge-requests"
      :title="s__('AdminAIPoweredFeatures|GitLab Duo for merge requests')"
    >
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'AdminAIPoweredFeatures|AI-native features that help users accomplish tasks during the lifecycle of a merge request. %{linkStart}Learn more.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.mergeRequestsHelpPage" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
      <template #content>
        <feature-settings-table-rows
          data-testid="duo-merge-requests-table-rows"
          :ai-feature-settings="mergeRequestFeatures"
          :is-loading="isLoading"
        />
      </template>
    </feature-settings-block>
    <feature-settings-block
      id="duo-issues"
      :title="s__('AdminAIPoweredFeatures|GitLab Duo for issues')"
    >
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'AdminAIPoweredFeatures|An AI-native feature that generates a summary of discussions on an issue. %{linkStart}Learn more.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.issuesHelpPage" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
      <template #content>
        <feature-settings-table-rows
          data-testid="duo-issues-table-rows"
          :ai-feature-settings="issueFeatures"
          :is-loading="isLoading"
        />
      </template>
    </feature-settings-block>
    <feature-settings-block
      id="other-duo-features"
      :title="s__('AdminAIPoweredFeatures|Other GitLab Duo features')"
    >
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'AdminAIPoweredFeatures|AI-native features that support users outside of Chat or Code Suggestions. %{linkStart}Learn more.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.otherGitLabDuoHelpPage" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
      <template #content>
        <feature-settings-table-rows
          data-testid="other-duo-features-table-rows"
          :ai-feature-settings="otherGitLabDuoFeatures"
          :is-loading="isLoading"
        />
      </template>
    </feature-settings-block>
  </div>
</template>
