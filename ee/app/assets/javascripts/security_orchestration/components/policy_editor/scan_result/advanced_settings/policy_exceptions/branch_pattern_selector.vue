<script>
import { GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createSourceBranchPatternObject } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/utils';
import BranchPatternItem from './branch_pattern_item.vue';

export default {
  BRANCHES_PATTERN_LINK: helpPagePath('user/project/repository/branches/protected'),
  i18n: {
    addPatternButton: s__('ScanResultPolicy|Add new criteria'),
    description: s__(
      'ScanResultPolicy|Define branch patterns that can bypass policy requirements using wildcards and regex patterns. Use * for simple wildcards or regex patterns for advanced matching. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
  name: 'BranchPatternSelector',
  components: {
    BranchPatternItem,
    GlButton,
    GlLink,
    GlSprintf,
  },
  props: {
    patterns: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      items: this.mapSelectedPatterns(this.patterns),
    };
  },
  computed: {
    hasPatterns() {
      return this.items.length > 0;
    },
  },
  methods: {
    addPattern() {
      this.items = [...this.items, createSourceBranchPatternObject()];
    },
    removePattern(id) {
      this.items = this.items.filter((item) => item.id !== id);
    },
    mapSelectedPatterns(patterns) {
      return patterns.length > 0
        ? patterns.map(createSourceBranchPatternObject)
        : [createSourceBranchPatternObject()];
    },
  },
};
</script>

<template>
  <div class="gl-p-5">
    <p class="gl-text-neutral-500" data-testid="pattern-header">
      <gl-sprintf :message="$options.i18n.description">
        <template #link="{ content }">
          <gl-link :href="$options.BRANCHES_PATTERN_LINK" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>

    <div v-if="hasPatterns" class="gl-mb-4 gl-flex gl-flex-col gl-gap-4">
      <branch-pattern-item
        v-for="item in items"
        :key="item.id"
        :pattern="item"
        @remove="removePattern(item.id)"
      />
    </div>

    <gl-button
      data-testid="add-pattern"
      icon="plus"
      category="tertiary"
      variant="confirm"
      size="small"
      @click="addPattern"
    >
      {{ $options.i18n.addPatternButton }}
    </gl-button>
  </div>
</template>
