<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { sortBy } from 'lodash';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import { DUO_MAIN_FEATURES } from 'ee/ai/shared/feature_settings/constants';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import FeatureSettingsTableRows from './feature_settings_table_rows.vue';

export default {
  name: 'ExpandedChatFeatureSettingsTable',
  components: {
    FeatureSettingsTableRows,
    GlAlert,
    GlLink,
    GlSprintf,
  },
  inject: ['betaModelsEnabled', 'duoConfigurationSettingsPath'],
  i18n: {
    errorMessage: s__(
      'AdminAIPoweredFeatures|An error occurred while loading the AI feature settings. Please try again.',
    ),
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
  data() {
    return {
      aiFeatureSettings: [],
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.loading;
    },
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
  apollo: {
    aiFeatureSettings: {
      query: getAiFeatureSettingsQuery,
      update(data) {
        return data.aiFeatureSettings?.nodes || [];
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          error,
          captureError: true,
        });
      },
    },
  },
  methods: {
    getSubFeatures(mainFeature) {
      const displayOrder = {
        GA: 1,
        BETA: 2,
        EXPERIMENT: 3,
      };

      const subFeatures = this.aiFeatureSettings.filter(
        (setting) => setting.mainFeature === mainFeature,
      );
      // sort rows by releaseState
      return sortBy(subFeatures, (subFeature) => displayOrder[subFeature.releaseState]);
    },
  },
};
</script>
<template>
  <div>
    <div class="gl-p-5 md:gl-py-6">
      <h2 class="gl-heading-2 gl-mb-2">{{ s__('AdminAIPoweredFeatures|Code Suggestions') }}</h2>
      <p class="gl-mb-0 gl-text-subtle">
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
      </p>
    </div>
    <feature-settings-table-rows
      data-testid="code-suggestions-table-rows"
      :ai-feature-settings="codeSuggestionsFeatures"
      :is-loading="isLoading"
    />
    <div class="gl-p-5 gl-pt-0 md:gl-py-6">
      <h2 class="gl-heading-2 gl-mb-2">{{ s__('AdminAIPoweredFeatures|GitLab Duo Chat') }}</h2>
      <p class="gl-mb-0 gl-text-subtle">
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
      </p>
    </div>
    <div v-if="!betaModelsEnabled" class="gl-pb-4">
      <gl-alert variant="info" :dismissible="false">
        <gl-sprintf
          :message="
            s__(
              'AdminSelfHostedModels|More features are available in beta. You can %{linkStart}turn on AI-native beta features%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link data-testid="duo-configuration-link" :href="duoConfigurationSettingsPath">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </gl-alert>
    </div>
    <feature-settings-table-rows
      data-testid="duo-chat-table-rows"
      :ai-feature-settings="duoChatFeatures"
      :is-loading="isLoading"
    />
    <template v-if="mergeRequestFeatures.length">
      <div class="gl-p-5 gl-pt-0 md:gl-py-6">
        <h2 class="gl-heading-2 gl-mb-2">
          {{ s__('AdminAIPoweredFeatures|GitLab Duo for merge requests') }}
        </h2>
        <p class="gl-mb-0 gl-text-subtle">
          <gl-sprintf
            :message="
              s__(
                'AdminAIPoweredFeatures|AI-native features that help users accomplish tasks during the lifecycle of a merge request. %{linkStart}Learn more.%{linkEnd}',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.mergeRequestsHelpPage" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
        </p>
      </div>
      <feature-settings-table-rows
        data-testid="duo-merge-requests-table-rows"
        :ai-feature-settings="mergeRequestFeatures"
        :is-loading="isLoading"
      />
    </template>
    <template v-if="issueFeatures.length">
      <div class="gl-p-5 gl-pt-0 md:gl-py-6">
        <h2 class="gl-heading-2 gl-mb-2">
          {{ s__('AdminAIPoweredFeatures|GitLab Duo for issues') }}
        </h2>
        <p class="gl-mb-0 gl-text-subtle">
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
        </p>
      </div>
      <feature-settings-table-rows
        data-testid="duo-issues-table-rows"
        :ai-feature-settings="issueFeatures"
        :is-loading="isLoading"
      />
    </template>
    <template v-if="otherGitLabDuoFeatures.length">
      <div class="gl-p-5 gl-pt-0 md:gl-py-6">
        <h2 class="gl-heading-2 gl-mb-2">
          {{ s__('AdminAIPoweredFeatures|Other GitLab Duo features') }}
        </h2>
        <p class="gl-mb-0 gl-text-subtle">
          <gl-sprintf
            :message="
              s__(
                'AdminAIPoweredFeatures|AI-native features that support users outside of Chat or Code Suggestions. %{linkStart}Learn more.%{linkEnd}',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.otherGitLabDuoHelpPage" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
        </p>
      </div>
      <div v-if="!betaModelsEnabled" class="gl-pb-4 gl-pt-2">
        <gl-alert variant="info" :dismissible="false">
          <gl-sprintf
            :message="
              s__(
                'AdminSelfHostedModels|More features are available in beta. You can %{linkStart}turn on AI-native beta features%{linkEnd}.',
              )
            "
          >
            <template #link="{ content }">
              <gl-link data-testid="duo-configuration-link" :href="duoConfigurationSettingsPath">
                {{ content }}
              </gl-link>
            </template>
          </gl-sprintf>
        </gl-alert>
      </div>
      <feature-settings-table-rows
        data-testid="other-duo-features-table-rows"
        :ai-feature-settings="otherGitLabDuoFeatures"
        :is-loading="isLoading"
      />
    </template>
  </div>
</template>
