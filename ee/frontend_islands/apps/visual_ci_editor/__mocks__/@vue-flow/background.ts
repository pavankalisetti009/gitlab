import { h, defineComponent } from 'vue';

export const Background = defineComponent({
  name: 'Background',
  props: {
    patternColor: { type: String, default: '#aaa' },
    gap: { type: Number, default: 10 },
  },
  setup() {
    return () => h('div', { 'data-testid': 'background' });
  },
});
