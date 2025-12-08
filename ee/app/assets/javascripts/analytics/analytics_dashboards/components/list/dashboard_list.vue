<script>
import {
  GlTable,
  GlAvatarLabeled,
  GlAvatarLink,
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlLink,
  GlTooltipDirective,
  GlTruncate,
} from '@gitlab/ui';

import { __, sprintf } from '~/locale';

export default {
  name: 'DashboardList',
  components: {
    GlTable,
    GlAvatarLabeled,
    GlAvatarLink,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlLink,
    GlTruncate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    dashboards: {
      type: Array,
      required: true,
    },
  },
  methods: {
    dashboardUrl(slug) {
      // NOTE: this should either be a URL or vue router redirect
      return `/${slug}`;
    },
    starIcon(isStarred) {
      return isStarred ? 'star' : 'star-o';
    },
    starTitle(isStarred) {
      return isStarred ? __('Remove from favorites') : __('Add to favorites');
    },
    starAriaLabel(name, isStarred) {
      const str = isStarred ? __('Remove %{name} from favorites') : __('Add %{name} to favorites');
      return sprintf(str, { name });
    },
  },
  actions: {
    items: [
      {
        text: __('Edit'),
        action: () => {},
      },
      {
        text: __('Make a copy'),
        action: () => {},
      },
      {
        text: __('Share'),
        action: () => {},
      },
    ],
  },
  additionalActions: {
    items: [
      {
        text: __('Delete'),
        action: () => {},
        variant: 'danger',
      },
    ],
  },
  avatarSize: 24,
  fields: [
    {
      key: 'name',
      label: __('Title'),
    },
    {
      key: 'createdBy',
      label: __('Created by'),
      tdClass: '!gl-align-bottom',
    },
    {
      key: 'lastEdited',
      label: __('Last edited'),
      tdClass: '!gl-align-middle',
    },
    {
      key: 'actions',
      tdClass: '!gl-text-right',
      label: __('Actions'),
    },
  ],
};
</script>
<template>
  <gl-table stacked="sm" :items="dashboards" :fields="$options.fields">
    <template #head(actions)="column"
      ><span class="gl-sr-only">{{ column.label }}</span></template
    >
    <template #cell(name)="{ item: { name, isStarred, description, slug } }">
      <div class="gl-inline-block gl-w-full gl-min-w-1 gl-flex-row gl-items-center sm:gl-flex">
        <gl-button
          class="sm:gl-mr-3"
          category="tertiary"
          variant="default"
          data-testid="dashboard-star-icon"
          :aria-label="starAriaLabel(name, isStarred)"
          :title="starTitle(isStarred)"
          :icon="starIcon(isStarred)"
        />

        <div class="gl-flex-1 gl-flex-col gl-text-right sm:gl-w-48 sm:gl-text-left">
          <gl-link
            data-testid="dashboard-redirect-link"
            :href="dashboardUrl(slug)"
            class="gl-font-bold gl-text-black !gl-no-underline"
            >{{ name }}</gl-link
          >
          <div>
            <gl-truncate :text="description" with-tooltip />
          </div>
        </div>
      </div>
    </template>
    <template #cell(createdBy)="{ item: { user } }">
      <gl-avatar-link target="_blank" :href="user.webUrl">
        <gl-avatar-labeled
          :src="user.avatarUrl"
          :size="$options.avatarSize"
          :label="user.name"
          shape="circle"
          fallback-on-error
        />
      </gl-avatar-link>
    </template>
    <template #cell(actions)="{ field }">
      <gl-disclosure-dropdown
        v-gl-tooltip.hover
        icon="ellipsis_v"
        category="tertiary"
        text-sr-only
        :title="field.label"
        :aria-label="field.label"
        no-caret
        left
        data-testid="dashboard-actions"
      >
        <gl-disclosure-dropdown-group :group="$options.actions" />
        <gl-disclosure-dropdown-group bordered :group="$options.additionalActions" />
      </gl-disclosure-dropdown>
    </template>
  </gl-table>
</template>
