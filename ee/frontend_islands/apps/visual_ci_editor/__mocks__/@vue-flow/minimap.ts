import { h, defineComponent } from 'vue';

export const MiniMap = defineComponent({
  name: 'MiniMap',
  setup() {
    return () => h('div', { 'data-testid': 'minimap' });
  },
});
