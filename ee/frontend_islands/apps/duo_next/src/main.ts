import { defineCustomElement } from 'vue';
import App from './App.vue';
import tailwind from './style.css?inline';

const DuoNextElement = defineCustomElement(App, {
  styles: [tailwind],
});

customElements.define('fe-island-duo-next', DuoNextElement);
