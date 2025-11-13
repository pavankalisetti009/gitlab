<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';

export default {
  name: 'AdminDataManagementItemApp',
  components: {
    PageHeading,
  },
};
</script>

<template>
  <page-heading :heading="__('Data management')" />
</template>
