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
      docsUrl: helpPagePath('user/duo_agent_platform/security'),
    };
  },
};
</script>

<template>
  <gl-alert variant="warning" :dismissible="false">
    <div>
      <p>{{ s__('AICatalog|When you enable this agent:') }}</p>
      <ul class="gl-pl-5">
        <li>{{ s__('AICatalog|All project members will be able to use it.') }}</li>
      </ul>
    </div>
    <div>
      <p>
        {{ s__('AICatalog|When this agent runs, it will have access to the projects:') }}
      </p>
      <ul class="gl-pl-5">
        <li>{{ s__('AICatalog|That the user who runs it has access to.') }}</li>
      </ul>
    </div>

    <p>{{ s__('AICatalog|Use caution when enabling.') }}</p>

    <p>
      <gl-link :href="docsUrl">{{ s__('AICatalog|Learn more') }}</gl-link
      >.
    </p>
  </gl-alert>
</template>
