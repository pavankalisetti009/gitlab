<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import getAiFeatureSettingsQuery from '../graphql/queries/get_ai_feature_settings.query.graphql';
import { DUO_MAIN_FEATURES } from '../../constants';
import FeatureSettingsTableRows from './feature_settings_table_rows.vue';

export default {
  name: 'ExpandedChatFeatureSettingsTable',
  components: {
    FeatureSettingsTableRows,
    GlLink,
    GlSprintf,
  },
  i18n: {
    errorMessage: s__(
      'AdminAIPoweredFeatures|An error occurred while loading the AI feature settings. Please try again.',
    ),
  },
  codeSuggestionsHelpPage: helpPagePath('user/project/repository/code_suggestions/_index'),
  duoChatHelpPage: helpPagePath('user/gitlab_duo_chat/_index'),
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
      return this.aiFeatureSettings.filter(
        (setting) => setting.mainFeature === DUO_MAIN_FEATURES.CODE_SUGGESTIONS,
      );
    },
    duoChatFeatures() {
      return this.aiFeatureSettings.filter(
        (setting) => setting.mainFeature === DUO_MAIN_FEATURES.DUO_CHAT,
      );
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
};
</script>
<template>
  <div>
    <div class="gl-p-5">
      <h2 class="gl-heading-2 gl-mb-3">{{ s__('AdminAIPoweredFeatures|Code Suggestions') }}</h2>
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
      <h2 class="gl-heading-2 gl-mb-3">{{ s__('AdminAIPoweredFeatures|GitLab Duo Chat') }}</h2>
      <p class="gl-mb-0 gl-text-subtle">
        <gl-sprintf
          :message="
            s__(
              'AdminAIPoweredFeatures|An AI assistant that provides real-time guidance helping users understand code, generate tests, and boost collaboration. %{linkStart}Learn more.%{linkEnd}',
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
  </div>
</template>
