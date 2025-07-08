<script>
import { GlButton } from '@gitlab/ui';
import LabelDrawer from './label_drawer.vue';

export default {
  components: {
    LabelDrawer,
    GlButton,
  },
  methods: {
    openDrawer(mode, item) {
      this.$refs.labelDrawer.open(mode, item);
    },
    addLabel() {
      this.openDrawer('add');
    },
    updateLabel() {
      this.openDrawer('edit', { id: 1, name: 'test', description: 'hello', color: '#eee' });
    },
    onSubmit(item) {
      // eslint-disable-next-line no-console
      console.log(item);
    },
    onDelete(item) {
      // eslint-disable-next-line no-console
      console.log(item);
    },
  },
};
</script>
<template>
  <div>
    <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
    <gl-button class="gl-m-3" @click="addLabel()">{{ 'Add Label' }}</gl-button>
    <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
    <gl-button class="gl-m-3" @click="updateLabel()">{{ 'Edit Label' }}</gl-button>

    <label-drawer ref="labelDrawer" @saved="onSubmit" @delete="onDelete" />
  </div>
</template>
