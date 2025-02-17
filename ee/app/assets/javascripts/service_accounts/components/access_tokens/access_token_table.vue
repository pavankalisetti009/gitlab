<script>
import {
  GlBadge,
  GlDisclosureDropdown,
  GlIcon,
  GlLink,
  GlSprintf,
  GlTable,
  GlTooltipDirective,
} from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { fallsBefore, nWeeksAfter } from '~/lib/utils/datetime_utility';
import { s__ } from '~/locale';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import UserDate from '~/vue_shared/components/user_date.vue';

export default {
  components: {
    GlBadge,
    GlDisclosureDropdown,
    GlIcon,
    GlLink,
    GlSprintf,
    GlTable,
    HelpIcon,
    TimeAgoTooltip,
    UserDate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    busy: {
      type: Boolean,
      required: true,
    },
    tokens: {
      type: Array,
      required: true,
    },
  },
  methods: {
    isExpiring(expiresAt) {
      if (expiresAt) {
        return fallsBefore(new Date(expiresAt), nWeeksAfter(new Date(), 2));
      }

      return false;
    },
  },
  usage: helpPagePath('/user/profile/personal_access_tokens.md', {
    anchor: 'view-token-usage-information',
  }),
  fields: [
    {
      key: 'name',
      label: s__('AccessTokens|Name'),
    },
    {
      key: 'status',
      label: s__('AccessTokens|Status'),
    },
    {
      formatter: (property) => (property?.length ? property.join(', ') : '-'),
      key: 'scopes',
      label: s__('AccessTokens|Scopes'),
      tdAttr: { 'data-testid': 'cell-scopes' },
    },
    {
      key: 'usage',
      label: s__('AccessTokens|Usage'),
      thAttr: { 'data-testid': 'header-usage' },
    },
    {
      key: 'lifetime',
      label: s__('AccessTokens|Lifetime'),
    },
    {
      key: 'options',
      label: '',
      tdClass: 'gl-text-end',
    },
  ],
  optionsItems: [
    {
      text: s__('AccessTokens|Rotate'),
    },
    {
      text: s__('AccessTokens|Revoke'),
      variant: 'danger',
    },
  ],
};
</script>

<template>
  <gl-table
    :items="tokens"
    :fields="$options.fields"
    :empty-text="s__('AccessTokens|No access tokens')"
    show-empty
    stacked="md"
    :busy="busy"
  >
    <template #head(usage)="{ label }">
      <span>{{ label }}</span>
      <gl-link :href="$options.usage"
        ><help-icon class="gl-ml-2" /><span class="gl-sr-only">{{
          s__('AccessTokens|View token usage information')
        }}</span></gl-link
      >
    </template>

    <template #cell(name)="{ item: { name, description } }">
      <div data-testid="field-name" class="gl-font-bold">{{ name }}</div>
      <div v-if="description" data-testid="field-description" class="gl-mt-3">
        {{ description }}
      </div>
    </template>

    <template #cell(status)="{ item: { active, revoked, expiresAt } }">
      <template v-if="active">
        <template v-if="isExpiring(expiresAt)">
          <gl-badge
            v-gl-tooltip
            :title="s__('AccessTokens|Token expires in less than two weeks.')"
            variant="warning"
            icon="expire"
            icon-optically-aligned
            >{{ s__('AccessTokens|Expiring') }}</gl-badge
          >
        </template>
        <template v-else>
          <gl-badge variant="success" icon="check-circle" icon-optically-aligned>{{
            s__('AccessTokens|Active')
          }}</gl-badge>
        </template>
      </template>
      <template v-else-if="revoked">
        <gl-badge variant="neutral" icon="remove" icon-optically-aligned>{{
          s__('AccessTokens|Revoked')
        }}</gl-badge>
      </template>
      <template v-else>
        <gl-badge variant="neutral" icon="time-out" icon-optically-aligned>{{
          s__('AccessTokens|Expired')
        }}</gl-badge>
      </template>
    </template>

    <template #cell(usage)="{ item: { lastUsedAt, lastUsedIps } }">
      <div data-testid="field-last-used">
        <span>{{ s__('AccessTokens|Last used:') }}</span>
        <time-ago-tooltip v-if="lastUsedAt" :time="lastUsedAt" />
        <template v-else>{{ __('Never') }}</template>
      </div>

      <div
        v-if="lastUsedIps && lastUsedIps.length"
        class="gl-mt-3"
        data-testid="field-last-used-ips"
      >
        <gl-sprintf
          :message="n__('AccessTokens|IP: %{ips}', 'AccessTokens|IPs: %{ips}', lastUsedIps.length)"
        >
          <template #ips>{{ lastUsedIps.join(', ') }}</template>
        </gl-sprintf>
      </div>
    </template>

    <template #cell(lifetime)="{ item: { createdAt, expiresAt } }">
      <div class="gl-flex gl-flex-col gl-gap-3 gl-justify-self-end md:gl-justify-self-start">
        <div class="gl-flex gl-gap-2 gl-whitespace-nowrap" data-testid="field-expires">
          <gl-icon
            v-gl-tooltip
            :aria-label="s__('AccessTokens|Expires')"
            :title="s__('AccessTokens|Expires')"
            name="time-out"
          />
          <time-ago-tooltip v-if="expiresAt" :time="expiresAt" />
          <span v-else>{{ s__('AccessTokens|Never until revoked') }}</span>
        </div>

        <div class="gl-flex gl-gap-2 gl-whitespace-nowrap" data-testid="field-created">
          <gl-icon
            v-gl-tooltip
            :aria-label="s__('AccessTokens|Created')"
            :title="s__('AccessTokens|Created')"
            name="clock"
          />
          <user-date :date="createdAt" />
        </div>
      </div>
    </template>

    <template #cell(options)="{ item: { active } }">
      <gl-disclosure-dropdown
        v-if="active"
        icon="ellipsis_v"
        :no-caret="true"
        :disabled="busy"
        category="tertiary"
        :fluid-width="true"
        :items="$options.optionsItems"
      />
    </template>
  </gl-table>
</template>
