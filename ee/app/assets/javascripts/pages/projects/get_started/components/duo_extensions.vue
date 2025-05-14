<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'DuoExtensions',
  components: { GlButton },
  data: () => {
    return {
      extensions: [
        {
          name: __('VS Code'),
          path: helpPagePath('editor_extensions/visual_studio_code/_index.md'),
        },
        { name: __('Jetbrains'), path: helpPagePath('editor_extensions/jetbrains_ide/_index.md') },
        {
          name: __('Visual Studio'),
          path: helpPagePath('editor_extensions/visual_studio/_index.md'),
        },
        { name: __('Eclipse'), path: helpPagePath('editor_extensions/eclipse/_index.md') },
        { name: __('Neovim'), path: helpPagePath('editor_extensions/neovim/_index.md') },
        { name: __('GitLab CLI'), path: helpPagePath('editor_extensions/gitlab_cli/_index.md') },
      ],
    };
  },
};
</script>
<template>
  <div>
    <header>
      <h2 class="gl-text-size-h2">{{ s__('GetStarted|Use GitLab Duo locally') }}</h2>
      <p class="gl-mb-0 gl-text-subtle">
        {{
          s__(
            'GetStarted|Download the extension to access GitLab features and GitLab Duo AI capabilities to handle everyday tasks.',
          )
        }}
      </p>
    </header>
    <gl-button
      v-for="ext in extensions"
      :key="ext.name"
      category="secondary"
      :href="ext.path"
      class="gl-mr-3 gl-mt-3"
    >
      {{ ext.name }}
    </gl-button>
  </div>
</template>
