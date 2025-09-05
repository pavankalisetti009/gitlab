<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

export default {
  WARN_MODE_HELP_PATH: helpPagePath(
    'user/application_security/policies/merge_request_approval_policies',
    { anchor: 'warn-mode' },
  ),
  BANNER_STORAGE_KEY: 'security_policies_warn_mode_banner_184',
  name: 'WarnModeBanner',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
    LocalStorageSync,
  },
  data() {
    return {
      alertDismissed: false,
    };
  },
  methods: {
    dismissAlert() {
      this.alertDismissed = true;
    },
  },
};
</script>

<template>
  <local-storage-sync v-model="alertDismissed" :storage-key="$options.BANNER_STORAGE_KEY">
    <gl-alert
      v-if="!alertDismissed"
      class="gl-mb-5"
      :dismissible="true"
      :title="__(`We've added something new!`)"
      @dismiss="dismissAlert"
    >
      <p class="gl-mb-3">
        <gl-sprintf
          :message="
            s__(
              'SecurityOrchestration|Now when you create/edit policies, %{strongStart}Warn Mode%{strongEnd} lets you evaluate policy impact without blocking development teams, reducing friction during policy rollouts:',
            )
          "
        >
          <template #strong="{ content }">
            <strong>{{ content }}</strong>
          </template>
        </gl-sprintf>
      </p>
      <ul>
        <li>
          {{ s__('SecurityOrchestration|Gather violation data and developer feedback') }}
        </li>
        <li>
          {{ s__('SecurityOrchestration|Make informed decisions before full enforcement') }}
        </li>
      </ul>
      <gl-link class="gl-ml-7" :href="$options.WARN_MODE_HELP_PATH" target="_blank">{{
        __('Learn more')
      }}</gl-link>
    </gl-alert>
  </local-storage-sync>
</template>
