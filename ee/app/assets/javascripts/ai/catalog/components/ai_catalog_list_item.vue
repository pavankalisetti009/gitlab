<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';

export default {
  name: 'AiCatalogListItem',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    itemTypeConfig: {
      type: Object,
      required: true,
    },
  },
  computed: {
    actionItems() {
      return this.itemTypeConfig.actionItems?.(this.item) || [];
    },
    showDeleteAction() {
      return this.itemTypeConfig.deleteActionItem?.showActionItem?.(this.item);
    },
    hasActionItems() {
      return this.actionItems.length > 0;
    },
    showActions() {
      return this.showDeleteAction || this.hasActionItems;
    },
    formattedItemId() {
      return getIdFromGraphQLId(this.item.id);
    },
    showItemRoute() {
      return {
        name: this.itemTypeConfig.showRoute,
        params: { id: this.formattedItemId },
      };
    },
    deleteActionText() {
      return this.itemTypeConfig.deleteActionItem.text || __('Delete');
    },
    visibilityLevel() {
      return this.item.public ? VISIBILITY_LEVEL_PUBLIC_STRING : VISIBILITY_LEVEL_PRIVATE_STRING;
    },
    visibilityIconName() {
      return VISIBILITY_TYPE_ICON[this.visibilityLevel];
    },
    visibilityTooltip() {
      return this.itemTypeConfig.visibilityTooltip?.[this.visibilityLevel];
    },
    visibilityLevelLabel() {
      return VISIBILITY_LEVEL_LABELS[this.visibilityLevel];
    },
  },
};
</script>

<template>
  <li
    data-testid="ai-catalog-item"
    class="gl-border-b gl-relative gl-flex gl-grow gl-cursor-pointer gl-items-start gl-justify-between gl-p-4 gl-pt-5 gl-transition-background hover:gl-bg-subtle"
  >
    <div class="gl-flex gl-min-w-0 gl-max-w-3xl gl-flex-col gl-gap-3">
      <h2 class="gl-heading-5 gl-m-0 gl-line-clamp-2 gl-text-ellipsis gl-p-0 @sm:gl-line-clamp-1">
        <router-link
          data-testid="ai-catalog-item-link"
          class="!gl-text-default !gl-no-underline after:gl-absolute after:gl-inset-0 after:gl-content-['']"
          :to="showItemRoute"
        >
          {{ item.name }}
        </router-link>
      </h2>
      <p
        class="gl-m-0 gl-line-clamp-3 gl-text-ellipsis gl-p-0 gl-text-subtle @sm:gl-line-clamp-2 @md:gl-line-clamp-1"
      >
        {{ item.description }}
      </p>
      <div class="gl-flex gl-shrink">
        <div
          v-if="visibilityTooltip"
          v-gl-tooltip
          data-testid="ai-catalog-item-tooltip"
          :title="visibilityTooltip"
          class="gl-z-1 gl-flex gl-items-center gl-gap-2"
        >
          <gl-icon :name="visibilityIconName" variant="subtle" :size="14" />
          <span class="gl-pt-px gl-text-subtle">{{ visibilityLevelLabel }}</span>
        </div>
      </div>
    </div>
    <gl-disclosure-dropdown
      v-if="showActions"
      :toggle-text="__('More actions')"
      category="tertiary"
      icon="ellipsis_v"
      class="gl-z-1"
      no-caret
      text-sr-only
    >
      <gl-disclosure-dropdown-group v-if="hasActionItems">
        <gl-disclosure-dropdown-item
          v-for="(actionItem, index) in actionItems"
          :key="index"
          :item="actionItem"
        >
          <template #list-item>
            <span>
              <gl-icon
                :name="actionItem.icon"
                class="gl-mr-2"
                variant="subtle"
                aria-hidden="true"
              />
              {{ actionItem.text }}
            </span>
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>
      <gl-disclosure-dropdown-group v-if="showDeleteAction" :bordered="hasActionItems">
        <gl-disclosure-dropdown-item variant="danger" @action="$emit('delete')">
          <template #list-item>
            <span>
              <gl-icon name="remove" class="gl-mr-2" variant="current" aria-hidden="true" />
              {{ deleteActionText }}
            </span>
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>
    </gl-disclosure-dropdown>
  </li>
</template>
