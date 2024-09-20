<script>
import { GlTable, GlIcon, GlButton, GlToggle } from '@gitlab/ui';
import { s__ } from '~/locale';

const i18nStrings = {
  status: s__('SecurityExclusions|Status'),
  type: s__('SecurityExclusions|Type'),
  value: s__('SecurityExclusions|Value'),
  enforcement: s__('SecurityExclusions|Enforcement'),
  modified: s__('SecurityExclusions|Modified'),
  headingText: s__(
    'SecurityExclusions|Specify file paths, raw values, and regex that should be excluded by secret detection in this project.',
  ),
  addExclusion: s__('SecurityExclusions|Add exclusion'),
  secretPushProtection: s__('SecurityExclusions|Secret push protection'),
  toggleLabel: s__('SecurityExclusions|Toggle exclusion'),
};

export default {
  name: 'ExclusionList',
  components: {
    GlTable,
    GlIcon,
    GlButton,
    GlToggle,
  },
  props: {
    exclusions: {
      type: Array,
      required: true,
    },
  },
  i18n: i18nStrings,
  data() {
    return {
      fields: [
        { key: 'status', label: this.$options.i18n.status },
        { key: 'type', label: this.$options.i18n.type, sortable: true },
        { key: 'content', label: this.$options.i18n.value },
        { key: 'enforcement', label: this.$options.i18n.enforcement },
        { key: 'modified', label: this.$options.i18n.modified },
        { key: 'actions', label: '' },
      ],
    };
  },
  methods: {
    addExclusion() {
      this.$emit('addExclusion');
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mb-3 gl-flex gl-items-baseline gl-justify-between">
      <p>
        {{ $options.i18n.headingText }}
      </p>
      <gl-button variant="confirm" @click="addExclusion">{{
        $options.i18n.addExclusion
      }}</gl-button>
    </div>

    <gl-table :items="exclusions" :fields="fields" stacked="md">
      <template #cell(status)="{ item }">
        <gl-toggle
          :value="item.active"
          :label="$options.i18n.toggleLabel"
          label-position="hidden"
        />
      </template>
      <template #cell(type)="{ item }">
        {{ item.type }}
      </template>
      <template #cell(content)="{ item }">
        {{ item.value }}
      </template>
      <template #cell(enforcement)>
        <gl-icon name="check" class="text-success" />
        {{ $options.i18n.secretPushProtection }}
      </template>
      <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
      <template #cell(modified)> {{ '3 days ago' }} </template>
      <template #cell(actions)>
        <gl-button icon="ellipsis_v" category="tertiary" />
      </template>
    </gl-table>
  </div>
</template>
