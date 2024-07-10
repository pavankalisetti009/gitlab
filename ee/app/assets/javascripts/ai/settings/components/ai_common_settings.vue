<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';

export default {
  name: 'AiCommonSettings',
  components: {
    GlLink,
    GlSprintf,
    SettingsBlock,
  },
  props: {
    largeTitle: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  aiFeaturesHelpPath: helpPagePath('user/ai_features'),
};
</script>
<template>
  <settings-block :title="s__('AiPowered|GitLab Duo features')" :large-title="largeTitle">
    <template #description>
      <gl-sprintf
        :message="
          s__(
            'AiPowered|Configure AI-powered GitLab Duo features. %{linkStart}Which features?%{linkEnd}',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.aiFeaturesHelpPath">{{ content }} </gl-link>
        </template>
      </gl-sprintf>
    </template>
  </settings-block>
</template>
