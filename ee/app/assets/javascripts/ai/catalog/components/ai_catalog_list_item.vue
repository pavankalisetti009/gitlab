<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
  GlTruncate,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';

export default {
  name: 'AiCatalogListItem',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    GlTruncate,
    GlIcon,
    FoundationalIcon,
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
    showDisableAction() {
      return this.itemTypeConfig.disableActionItem?.showActionItem?.(this.item);
    },
    hasActionItems() {
      return this.actionItems.length > 0;
    },
    showActions() {
      return this.showDisableAction || this.hasActionItems;
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
    disableActionItem() {
      return this.itemTypeConfig.disableActionItem.text || __('Disable');
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
    isSourceProjectNull() {
      return !this.item.project?.nameWithNamespace;
    },
    sourceProjectName() {
      return this.isSourceProjectNull
        ? s__('AICatalog|Private project')
        : this.item.project?.nameWithNamespace;
    },
    sourceProjectTooltip() {
      return this.isSourceProjectNull
        ? s__("AICatalog|Managed by a private project you don't have access to.")
        : this.item.project?.nameWithNamespace;
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
          class="!gl-text-default !gl-no-underline after:gl-absolute after:gl-inset-0 after:gl-content-['']"
          :to="showItemRoute"
        >
          {{ item.name }}
        </router-link>

        <foundational-icon
          v-if="item.foundationalChat"
          :resource-id="item.id"
          :size="16"
          class="gl-ml-1"
        />
      </h2>
      <p
        class="gl-m-0 gl-line-clamp-3 gl-text-ellipsis gl-p-0 gl-text-subtle @sm:gl-line-clamp-2 @md:gl-line-clamp-1"
      >
        {{ item.description }}
      </p>
      <div class="gl-z-1 gl-flex gl-shrink gl-gap-4">
        <div
          v-gl-tooltip
          :title="sourceProjectTooltip"
          data-testid="ai-catalog-item-source-project"
          class="gl-flex gl-items-center gl-gap-2"
        >
          <gl-icon
            :name="isSourceProjectNull ? 'eye-slash' : 'project'"
            variant="subtle"
            :size="14"
          />
          <gl-truncate class="gl-max-w-20 gl-pt-px gl-text-subtle" :text="sourceProjectName" />
        </div>
        <div
          v-if="visibilityTooltip"
          v-gl-tooltip
          :title="visibilityTooltip"
          data-testid="ai-catalog-item-visibility"
          class="gl-flex gl-items-center gl-gap-2"
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
      <gl-disclosure-dropdown-group v-if="showDisableAction" :bordered="hasActionItems">
        <gl-disclosure-dropdown-item @action="$emit('disable')">
          <template #list-item>
            <span>
              <gl-icon name="cancel" class="gl-mr-2" variant="current" aria-hidden="true" />
              {{ disableActionItem }}
            </span>
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>
    </gl-disclosure-dropdown>
  </li>
</template>
