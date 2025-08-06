<script>
import TreeRoot from 'ee/related_items_tree/components/tree_root.vue';

export default {
  components: {
    TreeRoot,
  },
  props: {
    parentItem: {
      type: Object,
      required: true,
    },
    children: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
};
</script>

<template>
  <tree-root :parent-item="parentItem" :children="children" />
</template>
