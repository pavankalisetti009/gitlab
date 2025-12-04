import { defineCustomElement } from 'vue';
import CommunicationLayer from './CommunicationLayer.vue';
import tailwind from './style.css?inline';

const VisualCiElement = defineCustomElement(CommunicationLayer, {
  styles: [tailwind],
});

customElements.define('fe-island-visual-ci-editor', VisualCiElement);
