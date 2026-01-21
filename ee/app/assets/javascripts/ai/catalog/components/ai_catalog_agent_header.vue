<script>
import { GlExperimentBadge } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { useAiBetaBadge } from 'ee/ai/duo_agents_platform/composables/use_ai_beta_badge';
import { AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from 'ee/ai/catalog/constants';

export default {
  name: 'DetailPageHeader',
  components: {
    GlExperimentBadge,
    PageHeading,
  },
  props: {
    heading: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    itemType: {
      type: String,
      required: false,
      default: null,
      validate: (value) =>
        [AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW, null].includes(value),
    },
  },
  computed: {
    isThirdPartyFlow() {
      return this.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
    showBetaBadge() {
      const { showBetaBadge } = useAiBetaBadge();
      return showBetaBadge.value;
    },
    badgeType() {
      if (this.isThirdPartyFlow) {
        return null;
      }

      if (this.showBetaBadge) {
        return 'beta';
      }

      return null;
    },
  },
};
</script>

<template>
  <page-heading>
    <template #heading>
      <span class="gl-flex">
        {{ heading }}
        <gl-experiment-badge v-if="badgeType" :type="badgeType" class="gl-self-center" />
      </span>
    </template>
    <template #description>
      {{ description }}
    </template>
  </page-heading>
</template>
