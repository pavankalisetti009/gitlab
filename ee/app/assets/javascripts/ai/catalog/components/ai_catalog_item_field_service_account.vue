<script>
import { GlLink, GlSprintf, GlButton } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { AI_CATALOG_ITEM_LABELS } from '../constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import ServiceAccountProjectMemberships from './service_account_project_memberships.vue';
import ServiceAccountAvatar from './service_account_avatar.vue';

export default {
  name: 'AiCatalogItemFieldServiceAccount',
  components: {
    GlLink,
    GlSprintf,
    GlButton,
    AiCatalogItemField,
    ServiceAccountProjectMemberships,
    ServiceAccountAvatar,
  },
  props: {
    serviceAccount: {
      type: Object,
      required: true,
    },
    itemType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isDrawerOpen: false,
    };
  },
  computed: {
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.itemType];
    },
  },
  methods: {
    openDrawer() {
      this.isDrawerOpen = true;
    },
    closeDrawer() {
      this.isDrawerOpen = false;
    },
  },
  serviceAccountsDocsLink: helpPagePath('user/profile/service_accounts'),
};
</script>

<template>
  <ai-catalog-item-field :title="s__('AICatalog|Service account')">
    <p class="gl-mb-0 gl-text-subtle">
      <gl-sprintf
        :message="
          s__(
            'AICatalog|%{linkStart}Service accounts%{linkEnd} represent non-human entities. This is the account that you mention or assign to trigger the %{itemType}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.serviceAccountsDocsLink">{{ content }}</gl-link>
        </template>
        <template #itemType>{{ itemTypeLabel }}</template>
      </gl-sprintf>
    </p>
    <service-account-avatar :service-account="serviceAccount" class="gl-mt-3" />
    <br />
    <gl-button category="tertiary" variant="link" class="gl-mt-3" @click="openDrawer">
      {{ s__('AICatalog|View projects and permissions of this service account') }}
    </gl-button>
    <service-account-project-memberships
      :service-account="serviceAccount"
      :is-open="isDrawerOpen"
      @close="closeDrawer"
    />
  </ai-catalog-item-field>
</template>
