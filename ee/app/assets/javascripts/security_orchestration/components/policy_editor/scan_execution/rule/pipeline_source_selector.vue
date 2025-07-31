<script>
import { TARGETS_BRANCHES_PIPELINE_SOURCE_OPTIONS, PIPELINE_SOURCE_OPTIONS } from '../constants';
import RuleMultiSelect from '../../rule_multi_select.vue';

export default {
  name: 'PipelineSourceSelector',
  components: {
    RuleMultiSelect,
  },
  props: {
    showAllSources: {
      type: Boolean,
      required: false,
      default: true,
    },
    pipelineSources: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    sources() {
      return Object.keys(this.items);
    },
    items() {
      return this.showAllSources
        ? PIPELINE_SOURCE_OPTIONS
        : TARGETS_BRANCHES_PIPELINE_SOURCE_OPTIONS;
    },
    selectedSources() {
      return this.pipelineSources?.including || this.sources;
    },
  },
  methods: {
    setPipelineSources(values) {
      // Early return for "select all" case
      if (values.length === this.sources.length) {
        this.$emit('remove');
        return;
      }

      // Emit selection with null for empty arrays, otherwise use the values
      const including = values.length ? values : null;
      this.$emit('select', { pipeline_sources: { including } });
    },
  },
};
</script>

<template>
  <rule-multi-select
    class="!gl-inline gl-align-middle"
    data-testid="pipeline-source"
    :item-type-name="s__('SecurityOrchestration|pipeline sources')"
    :items="items"
    :value="selectedSources"
    @input="setPipelineSources"
  />
</template>
