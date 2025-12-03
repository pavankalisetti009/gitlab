import { h, defineComponent } from 'vue';

export const VueFlow = defineComponent({
  name: 'VueFlow',
  props: {
    nodes: { type: Array, default: () => [] },
    edges: { type: Array, default: () => [] },
    fitViewOnInit: { type: Boolean, default: false },
    defaultZoom: { type: Number, default: 1 },
    minZoom: { type: Number, default: 0.5 },
    maxZoom: { type: Number, default: 2 },
  },
  setup(_, { slots }) {
    return () => h('div', { class: 'vue-flow-mock', 'data-testid': 'vue-flow' }, slots.default?.());
  },
});
