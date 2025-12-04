<script setup lang="ts">
import { ref } from 'vue';
import { VueFlow } from '@vue-flow/core';
import type { Node, Edge } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { MiniMap } from '@vue-flow/minimap';

const nodes = ref<Node[]>([
  {
    id: '1',
    type: 'input',
    position: { x: 250, y: 5 },
    data: { label: 'Node 1' },
  },
  {
    id: '2',
    position: { x: 100, y: 100 },
    data: { label: 'Node 2' },
  },
  {
    id: '3',
    type: 'output',
    position: { x: 400, y: 200 },
    data: { label: 'Node 3' },
  },
]);

const edges = ref<Edge[]>([
  {
    id: 'e1->2',
    source: '1',
    target: '2',
  },
  {
    id: 'e2->3',
    source: '2',
    target: '3',
    animated: true,
  },
]);
</script>

<template>
  <VueFlow
    :nodes="nodes"
    :edges="edges"
    fit-view-on-init
    :default-zoom="1.5"
    :min-zoom="0.2"
    :max-zoom="4"
  >
    <Background pattern-color="#A2A1A6" :gap="8" />
    <Controls />
    <MiniMap />
  </VueFlow>
</template>
