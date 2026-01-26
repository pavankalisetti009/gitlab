<script>
import { GlAvatarLabeled, GlAvatarLink, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { AI_CATALOG_ITEM_LABELS } from '../constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';

export default {
  name: 'AiCatalogItemFieldServiceAccount',
  components: {
    GlAvatarLabeled,
    GlAvatarLink,
    GlLink,
    GlSprintf,
    AiCatalogItemField,
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
  computed: {
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.itemType];
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
    <gl-avatar-link :href="serviceAccount.webPath" :title="serviceAccount.name" class="gl-mt-3">
      <gl-avatar-labeled
        :size="32"
        :src="serviceAccount.avatarUrl"
        :label="serviceAccount.name"
        :sub-label="`@${serviceAccount.username}`"
      />
    </gl-avatar-link>
  </ai-catalog-item-field>
</template>
