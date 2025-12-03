// Canvas_spec.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, VueWrapper } from '@vue/test-utils';
import type { Node, Edge } from '@vue-flow/core';

vi.mock('@vue-flow/core');
vi.mock('@vue-flow/background');
vi.mock('@vue-flow/controls');
vi.mock('@vue-flow/minimap');

import Canvas from './Canvas.vue';

describe('Canvas', () => {
  let wrapper: VueWrapper;

  beforeEach(() => {
    wrapper = mount(Canvas);
  });

  describe('rendering', () => {
    it('renders the VueFlow component', () => {
      expect(wrapper.find('[data-testid="vue-flow"]').exists()).toBe(true);
    });

    it('renders the Background component', () => {
      expect(wrapper.find('[data-testid="background"]').exists()).toBe(true);
    });

    it('renders the Controls component', () => {
      expect(wrapper.find('[data-testid="controls"]').exists()).toBe(true);
    });

    it('renders the MiniMap component', () => {
      expect(wrapper.find('[data-testid="minimap"]').exists()).toBe(true);
    });
  });

  describe('VueFlow props', () => {
    it('passes the correct number of nodes', () => {
      const vueFlow = wrapper.findComponent({ name: 'VueFlow' });
      expect(vueFlow.props('nodes')).toHaveLength(3);
    });

    it('passes the correct number of edges', () => {
      const vueFlow = wrapper.findComponent({ name: 'VueFlow' });
      expect(vueFlow.props('edges')).toHaveLength(2);
    });

    it('passes zoom configuration props', () => {
      const vueFlow = wrapper.findComponent({ name: 'VueFlow' });
      expect(vueFlow.props('defaultZoom')).toBe(1.5);
      expect(vueFlow.props('minZoom')).toBe(0.2);
      expect(vueFlow.props('maxZoom')).toBe(4);
    });

    it('enables fit-view-on-init', () => {
      const vueFlow = wrapper.findComponent({ name: 'VueFlow' });
      expect(vueFlow.props('fitViewOnInit')).toBe(true);
    });
  });

  describe('graph structure', () => {
    it('all edge sources reference existing nodes', () => {
      const vueFlow = wrapper.findComponent({ name: 'VueFlow' });
      const nodes = vueFlow.props('nodes') as Node[];
      const edges = vueFlow.props('edges') as Edge[];
      const nodeIds = nodes.map((n) => n.id);

      edges.forEach((edge) => {
        expect(nodeIds).toContain(edge.source);
      });
    });

    it('all edge targets reference existing nodes', () => {
      const vueFlow = wrapper.findComponent({ name: 'VueFlow' });
      const nodes = vueFlow.props('nodes') as Node[];
      const edges = vueFlow.props('edges') as Edge[];
      const nodeIds = nodes.map((n) => n.id);

      edges.forEach((edge) => {
        expect(nodeIds).toContain(edge.target);
      });
    });
  });
});
