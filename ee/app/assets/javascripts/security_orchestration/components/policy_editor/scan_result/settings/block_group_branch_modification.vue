<script>
import {
  GlCollapsibleListbox,
  GlFormInput,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  BLOCK_GROUP_BRANCH_MODIFICATION_WITH_BRANCH_HUMANIZED_STRING,
  BLOCK_GROUP_BRANCH_MODIFICATION_HUMANIZED_STRING,
} from '../lib';
import {
  EXCEPT_BRANCHES,
  EXCEPTION_BRANCH_TYPE_TEXTS,
  EXCEPTION_BRANCH_TYPE_LISTBOX_ITEMS,
  WITHOUT_EXCEPTIONS,
} from '../lib/settings';

export default {
  name: 'BlockGroupBranchModification',
  components: {
    GlCollapsibleListbox,
    GlFormInput,
    GlLink,
    GlSprintf,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    enabled: {
      type: Boolean,
      required: true,
    },
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      selectedExceptionType: this.exceptions.length ? EXCEPT_BRANCHES : WITHOUT_EXCEPTIONS,
      branchWildcardPattern: this.exceptions.join(','),
    };
  },
  computed: {
    text() {
      return this.selectedExceptionType === WITHOUT_EXCEPTIONS
        ? BLOCK_GROUP_BRANCH_MODIFICATION_HUMANIZED_STRING
        : BLOCK_GROUP_BRANCH_MODIFICATION_WITH_BRANCH_HUMANIZED_STRING;
    },
  },
  watch: {
    enabled(value) {
      if (value) {
        this.selectExceptionType(this.selectedExceptionType);
      } else {
        this.selectExceptionType(WITHOUT_EXCEPTIONS);
      }
    },
  },
  methods: {
    selectExceptionType(type) {
      this.selectedExceptionType = type;
      if (type === WITHOUT_EXCEPTIONS) {
        this.resetBranchWildcardPattern();
      }

      if (this.enabled) {
        const value =
          type === EXCEPT_BRANCHES
            ? { enabled: this.enabled, exceptions: this.exceptions }
            : this.enabled;
        this.emitChangeEvent(value);
      }
    },
    resetBranchWildcardPattern() {
      this.branchWildcardPattern = '';
    },
    updateBranchWildcardPattern(value) {
      this.branchWildcardPattern = value;
      if (this.enabled) {
        this.emitChangeEvent({ enabled: this.enabled, exceptions: value.split(',') });
      }
    },
    emitChangeEvent(value) {
      this.$emit('change', value);
    },
  },
  GROUP_PROTECTED_BRANCHES_DOCS: helpPagePath('user/project/repository/branches/protected', {
    anchor: 'for-all-projects-in-a-group',
  }),
  EXCEPTION_BRANCH_TYPE_TEXTS,
  EXCEPTION_BRANCH_TYPE_LISTBOX_ITEMS,
};
</script>

<template>
  <div>
    <gl-sprintf :message="text">
      <template #link="{ content }">
        <gl-link :href="$options.GROUP_PROTECTED_BRANCHES_DOCS" target="_blank">{{
          content
        }}</gl-link>
      </template>
      <template #exceptSelection>
        <gl-collapsible-listbox
          class="gl-my-3 gl-mr-2 md:gl-my-0"
          :items="$options.EXCEPTION_BRANCH_TYPE_LISTBOX_ITEMS"
          :selected="selectedExceptionType"
          @select="selectExceptionType"
        />
      </template>
      <template #projectSelection>
        <gl-form-input
          class="gl-inline-block md:gl-max-w-20"
          :value="branchWildcardPattern"
          :placeholder="s__('SecurityOrchestration|Ex: development/*')"
          @input="updateBranchWildcardPattern"
        />
      </template>
    </gl-sprintf>
  </div>
</template>
