<script>
import { GlAlert, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'AddGroupThirdPartyFlowWarning',
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
        <li>
          {{
            s__(
              'AICatalog|A service account will be added to the project and assigned the Developer role.',
            )
          }}
        </li>
      </ul>
    </div>
    <p>
      {{
        s__(
          "AICatalog|The service account is part of a composite identity that runs the agent. This identity combines the user's role with the service account's role and uses the more restrictive of the two.",
        )
      }}
    </p>
    <div>
      <p>
        {{ s__('AICatalog|When this agent runs, it will have access to the projects:') }}
      </p>
      <ul class="gl-pl-5">
        <li>{{ s__('AICatalog|That the user who runs it has access to.') }}</li>
        <li>
          {{
            s__(
              "AICatalog|That it's been enabled for. These are the projects the service account was added to.",
            )
          }}
        </li>
      </ul>
    </div>

    <p>{{ s__('AICatalog|Use caution when enabling.') }}</p>

    <p>
      <gl-link :href="docsUrl">{{ s__('AICatalog|Learn more') }}</gl-link
      >.
    </p>
  </gl-alert>
</template>
