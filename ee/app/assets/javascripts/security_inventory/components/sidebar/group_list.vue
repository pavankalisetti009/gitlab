<script>
import SubgroupsQuery from '../../graphql/subgroups.query.graphql';
import ExpandableGroup from './expandable_group.vue';

export default {
  components: {
    ExpandableGroup,
  },
  props: {
    groupFullPath: {
      type: String,
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
      group: {
        descendantGroups: {
          nodes: [],
        },
      },
    };
  },
  apollo: {
    group: {
      query: SubgroupsQuery,
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
    },
  },
  methods: {
    selectSubgroup(subgroupFullPath) {
      this.$emit('selectSubgroup', subgroupFullPath);
    },
  },
};
</script>
<template>
  <div>
    <expandable-group
      v-for="subgroup in group.descendantGroups.nodes"
      :key="subgroup.id"
      :group="subgroup"
      :active-full-path="activeFullPath"
      :indentation="indentation"
      @selectSubgroup="selectSubgroup"
    />
  </div>
</template>
