<script>
import { GlIcon, GlLink } from '@gitlab/ui';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import { sprintf, n__, __ } from '~/locale';
import { isSubGroup } from '../utils';

export default {
  components: {
    GlIcon,
    GlLink,
    ProjectAvatar,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    componentName() {
      return isSubGroup(this.item) ? GlLink : 'div';
    },
    linkHref() {
      return isSubGroup(this.item) && this.item.fullPath ? `#${this.item.fullPath}` : undefined;
    },
  },
  methods: {
    isSubGroup,
    iconName(item) {
      return this.isSubGroup(item) ? 'subgroup' : 'project';
    },
    projectAndSubgroupCountText(item) {
      const projectsCount = n__('%d project', '%d projects', item.projectsCount || 0);
      const subGroupsCount = n__('%d subgroup', '%d subgroups', item.descendantGroupsCount || 0);

      return sprintf(__('%{projectsCount}, %{subGroupsCount}'), {
        projectsCount,
        subGroupsCount,
      });
    },
  },
};
</script>

<template>
  <component
    :is="componentName"
    class="gl-flex gl-items-center !gl-text-default hover:gl-no-underline focus:gl-no-underline focus:gl-outline-none"
    :href="linkHref"
    :aria-label="isSubGroup(item) ? `Open subgroup ${item.name}` : undefined"
  >
    <gl-icon :name="iconName(item)" variant="subtle" class="gl-mr-4 gl-shrink-0" />
    <project-avatar
      class="gl-mr-4"
      :project-id="item.id"
      :project-name="item.name"
      :project-avatar-url="item.avatarUrl"
    />
    <div class="gl-flex gl-flex-col">
      <span class="gl-text-base gl-font-bold">{{ item.name }}</span>
      <span v-if="isSubGroup(item)" class="gl-font-normal gl-text-subtle">
        {{ projectAndSubgroupCountText(item) }}
      </span>
    </div>
  </component>
</template>
