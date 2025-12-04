import { h, defineComponent } from 'vue';

export const Controls = defineComponent({
  name: 'Controls',
  setup() {
    return () => h('div', { 'data-testid': 'controls' });
  },
});
