<script>
import { GlAlert, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'AddGroupAgentWarning',
  components: {
    GlAlert,
    GlLink,
  },
  data() {
    return {
      docsUrl: helpPagePath('user/duo_agent_platform/composite_identity'),
    };
  },
};
</script>

<template>
  <gl-alert variant="warning" :dismissible="false">
    <ul class="gl-pl-5">
      <li>
        {{
          s__('AICatalog|When you enable this agent, all project members will be able to use it.')
        }}
      </li>
      <li>
        {{
          s__(
            'AICatalog|When this agent runs, it will have access to the projects the user who runs it has access to.',
          )
        }}
      </li>
      <li>
        {{ s__('AICatalog|Use caution when enabling.') }}
        <gl-link :href="docsUrl">{{ __('Learn more') }}</gl-link
        >.
      </li>
    </ul>
  </gl-alert>
</template>
