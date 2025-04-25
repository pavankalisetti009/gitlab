<script>
import { GlButton, GlCard } from '@gitlab/ui';
import TANUNKI_AI_ICON from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { SUPPORT_URL } from '~/sessions/new/constants';

export default {
  name: 'DuoCoreUpgradeCard',
  components: {
    GlButton,
    GlCard,
  },
  inject: {
    addDuoProHref: { default: '' },
  },
  TANUNKI_AI_ICON,
  SUPPORT_URL,
};
</script>
<template>
  <gl-card
    footer-class="gl-bg-transparent gl-border-none gl-flex-end gl-flex gl-flex-wrap gl-gap-3"
    class="gl-justify-between"
  >
    <template #default>
      <div class="gl-flex">
        <img
          :src="$options.TANUNKI_AI_ICON"
          :alt="s__('AiPowered|Tanuki AI icon')"
          class="gl-pointer-events-none gl-size-10"
        />
        <div class="gl-ml-4">
          <h2 class="gl-m-0 gl-text-lg">{{ s__('AiPowered|Upgrade to') }}</h2>
          <p class="gl-mb-3 gl-text-size-h-display gl-font-bold">
            {{ s__('AiPowered|GitLab Duo Pro or Enterprise') }}
          </p>
        </div>
      </div>
      <p class="gl-mb-0 gl-mt-3">
        {{
          s__(
            'AiPowered|Unlock advanced AI-powered capabilities with the Premium or Ultimate tier designed for your development needs.',
          )
        }}
      </p>
    </template>
    <template #footer>
      <gl-button
        :href="addDuoProHref"
        variant="confirm"
        category="primary"
        data-testid="duo-core-upgrade-duo-pro-action"
      >
        {{ s__('AiPowered|Purchase Duo Pro seats') }}
      </gl-button>

      <gl-button
        :href="$options.SUPPORT_URL"
        variant="default"
        category="secondary"
        data-testid="duo-core-upgrade-duo-enterprise-action"
      >
        {{ s__('AiPowered|Contact sales for Duo Enterprise') }}
      </gl-button>
    </template>
  </gl-card>
</template>
