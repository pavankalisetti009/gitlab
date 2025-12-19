<script>
import { GlAlert, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'AddFlowWarning',
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
    <div>
      <p class="gl-mb-0">{{ s__('AICatalog|When you enable this flow:') }}</p>
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
          "AICatalog|The service account is part of a composite identity that runs the flow. This identity combines the user's role with the service account's role and uses the more restrictive of the two.",
        )
      }}
    </p>
    <div>
      <p class="gl-mb-0">
        {{ s__('AICatalog|When this flow runs, it will have access to the projects:') }}
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

    <p class="gl-mb-0">
      {{ s__('AICatalog|Use caution when enabling.') }}
      <gl-link :href="docsUrl">{{ __('Learn more') }}</gl-link
      >.
    </p>
  </gl-alert>
</template>
