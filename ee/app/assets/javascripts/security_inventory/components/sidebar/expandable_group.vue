<script>
import { GlBadge, GlButton, GlIcon } from '@gitlab/ui';
import TooltipOnTruncate from '~/vue_shared/directives/tooltip_on_truncate';
import { SIDEBAR_INDENTATION_INCREMENT } from '../../constants';

export default {
  components: {
    GlBadge,
    GlButton,
    GlIcon,
    GroupList: () => import('./group_list.vue'),
  },
  directives: {
    TooltipOnTruncate,
  },
  props: {
    group: {
      type: Object,
      required: true,
    },
    activeFullPath: {
      type: String,
      required: false,
      default: '',
    },
    indentation: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  data() {
    return {
      expanded: false,
    };
  },
  computed: {
    isActiveGroup() {
      return this.activeFullPath === this.group.fullPath;
    },
    containsActiveGroup() {
      return this.activeFullPath.startsWith(`${this.group.fullPath}/`);
    },
  },
  watch: {
    activeFullPath() {
      this.expandIfContainsActiveGroup();
    },
  },
  mounted() {
    this.expandIfContainsActiveGroup();
  },
  methods: {
    toggleExpanded(event) {
      event.stopPropagation();
      this.expanded = !this.expanded;
    },
    selectSubgroup(subgroupFullPath) {
      this.$emit('selectSubgroup', subgroupFullPath);
    },
    expandIfContainsActiveGroup() {
      if (this.containsActiveGroup) this.expanded = true;
    },
  },
  SIDEBAR_INDENTATION_INCREMENT,
};
</script>
<template>
  <div>
    <div
      class="gl-flex gl-h-8 gl-cursor-pointer gl-items-center gl-gap-4 gl-rounded-base gl-px-3 hover:!gl-bg-gray-100"
      :class="{ 'gl-bg-neutral-50': isActiveGroup }"
      data-testid="subgroup"
      :style="{ marginLeft: `${indentation}px` }"
      @click="selectSubgroup(group.fullPath)"
    >
      <gl-icon name="subgroup" variant="subtle" class="gl-mx-2 gl-shrink-0" />
      <div
        v-tooltip-on-truncate="group.name"
        class="gl-grow gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
        data-testid="subgroup-name"
      >
        {{ group.name }}
      </div>

      <gl-badge v-if="group.projectsCount" icon="project">
        {{ group.projectsCount }}
      </gl-badge>

      <gl-button
        v-if="group.descendantGroupsCount"
        :icon="expanded ? 'chevron-down' : 'chevron-right'"
        category="tertiary"
        size="small"
        icon-only
        @click="toggleExpanded"
      />
    </div>
    <group-list
      v-if="expanded"
      :group-full-path="group.fullPath"
      :active-full-path="activeFullPath"
      :selected-subgroup="activeFullPath"
      :indentation="indentation + $options.SIDEBAR_INDENTATION_INCREMENT"
      @selectSubgroup="selectSubgroup"
    />
  </div>
</template>
