<script>
import { GlDrawer } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import ExclusionForm from './exclusion_form.vue';

export default {
  components: {
    GlDrawer,
    ExclusionForm,
  },
  data() {
    return {
      isOpen: false,
      form: {
        name: '',
        description: '',
        type: '',
      },
    };
  },
  methods: {
    open() {
      this.isOpen = true;
    },
    close() {
      this.isOpen = false;
    },
    submit() {
      this.$emit('updated');
      this.close();
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :header-sticky="true"
    :open="isOpen"
    size="md"
    class="exclusion-form-drawer"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="close"
  >
    <template #header>
      <h3>{{ __('Add exclusion') }}</h3>
    </template>

    <exclusion-form :form="form" @saved="submit" @cancel="close" />
  </gl-drawer>
</template>
