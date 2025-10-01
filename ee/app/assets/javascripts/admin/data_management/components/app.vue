<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';

export default {
  name: 'AdminDataManagementApp',
  components: {
    PageHeading,
  },
};
</script>

<template>
  <page-heading>
    <template #heading>
      {{ __('Data management') }}
    </template>
  </page-heading>
</template>
