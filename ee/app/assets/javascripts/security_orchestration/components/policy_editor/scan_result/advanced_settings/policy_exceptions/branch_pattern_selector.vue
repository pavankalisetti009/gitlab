<script>
import { GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  createSourceBranchPatternObject,
  removeIds,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/utils';
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
    branches: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      items: this.mapSelectedBranches(this.branches),
    };
  },
  computed: {
    hasBranches() {
      return this.items.length > 0;
    },
  },
  methods: {
    addBranchPattern() {
      this.items = [...this.items, createSourceBranchPatternObject()];
    },
    setBranch(branch, index) {
      this.items.splice(index, 1, branch);
      this.$emit('set-branches', removeIds(this.items));
    },
    removeBranchPattern(id) {
      this.items = this.items.filter((item) => item.id !== id);
      this.$emit('set-branches', removeIds(this.items));
    },
    mapSelectedBranches(branches) {
      return branches.length > 0
        ? branches.map(createSourceBranchPatternObject)
        : [createSourceBranchPatternObject()];
    },
  },
};
</script>

<template>
  <div class="gl-p-5">
    <p class="gl-text-neutral-300" data-testid="pattern-header">
      <gl-sprintf :message="$options.i18n.description">
        <template #link="{ content }">
          <gl-link :href="$options.BRANCHES_PATTERN_LINK" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>

    <div v-if="hasBranches" class="gl-mb-4 gl-flex gl-flex-col gl-gap-4">
      <branch-pattern-item
        v-for="(item, index) in items"
        :key="item.id"
        :branch="item"
        @set-branch="setBranch($event, index)"
        @remove="removeBranchPattern(item.id)"
      />
    </div>

    <gl-button
      data-testid="add-branch-pattern"
      icon="plus"
      category="tertiary"
      variant="confirm"
      size="small"
      @click="addBranchPattern"
    >
      {{ $options.i18n.addPatternButton }}
    </gl-button>
  </div>
</template>
