<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import ListItem from '~/vue_shared/components/resource_lists/list_item.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import { AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';

export default {
  name: 'AiCatalogListItem',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    GlIcon,
    ListItem,
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
    canAdmin() {
      return Boolean(this.item.userPermissions.adminAiCatalogItem);
    },
    formattedItemId() {
      return getIdFromGraphQLId(this.item.id);
    },
    showItemRoute() {
      return {
        name: this.$route.name,
        query: { [AI_CATALOG_SHOW_QUERY_PARAM]: this.formattedItemId },
      };
    },
    formattedItem() {
      return {
        ...this.item,
        id: this.formattedItemId,
        avatarLabel: this.item.name,
        avatarUrl: null,
        fullName: this.item.name,
        descriptionHtml: this.item.description,
        relativeWebUrl: this.$router.resolve(this.showItemRoute).href,
      };
    },
    visibilityLevel() {
      return this.item.public ? VISIBILITY_LEVEL_PUBLIC_STRING : VISIBILITY_LEVEL_PRIVATE_STRING;
    },
    visibilityIconName() {
      return VISIBILITY_TYPE_ICON[this.visibilityLevel];
    },
    visibilityTooltip() {
      return this.itemTypeConfig.visibilityTooltip[this.visibilityLevel];
    },
  },
  methods: {
    onClickAvatar(event) {
      // The List Item uses GlAvatarLabeled internally. This component uses GlLink, which
      // would support `href` and `to` (Vue Router Location). However, GlAvatarLabeled currently
      // only supports href. This is why although setting the href which allows user to use right
      // click to open the URL in a new tab, we programmitcally push a new route when clicked
      // https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/blob/main/packages/gitlab-ui/src/components/base/avatar_labeled/avatar_labeled.vue#L80
      // This can be removed once this issue is resolved:
      // https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2935
      event.preventDefault();
      this.$router.push({
        query: { [AI_CATALOG_SHOW_QUERY_PARAM]: this.formattedItemId },
      });
    },
  },
};
</script>

<template>
  <list-item :resource="formattedItem" @click-avatar="(event) => onClickAvatar(event)">
    <template #avatar-meta>
      <gl-icon
        v-gl-tooltip
        :name="visibilityIconName"
        :title="visibilityTooltip"
        variant="subtle"
      />
    </template>
    <template #actions>
      <gl-disclosure-dropdown
        v-if="canAdmin"
        :toggle-text="__('More actions')"
        category="tertiary"
        icon="ellipsis_v"
        no-caret
        text-sr-only
      >
        <gl-disclosure-dropdown-group>
          <gl-disclosure-dropdown-item
            v-for="(actionItem, index) in itemTypeConfig.actionItems(formattedItemId)"
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
        <gl-disclosure-dropdown-group bordered>
          <gl-disclosure-dropdown-item variant="danger" @action="$emit('delete')">
            <template #list-item>
              <span>
                <gl-icon name="remove" class="gl-mr-2" variant="current" aria-hidden="true" />
                {{ __('Delete') }}
              </span>
            </template>
          </gl-disclosure-dropdown-item>
        </gl-disclosure-dropdown-group>
      </gl-disclosure-dropdown>
      <div v-else></div>
    </template>
  </list-item>
</template>
