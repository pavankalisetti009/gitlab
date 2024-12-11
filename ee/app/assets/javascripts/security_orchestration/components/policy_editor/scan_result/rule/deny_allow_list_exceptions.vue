<script>
import { debounce } from 'lodash';
import { GlCollapsibleListbox, GlFormTextarea } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import {
  EXCEPTION_KEY,
  EXCEPTION_TYPE_ITEMS,
  NO_EXCEPTION_KEY,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  mapObjectsToString,
  findItemsWithErrors,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

export default {
  i18n: {
    exceptionMessage: s__(
      'ScanResultPolicy|Use this format for package paths: path/file.yaml@group-name/project-name. For multiple packages, separate paths with comma ",".',
    ),
    errorMessage: s__(
      'SecurityOrchestration|Add project full path after @ to following exceptions: %{exceptions}',
    ),
    duplicatesError: s__('ScanResultPolicy|Duplicates will be removed'),
  },
  EXCEPTION_TYPE_ITEMS: [
    {
      value: EXCEPTION_KEY,
      text: s__('SecurityOrchestration|Except'),
    },
    {
      value: NO_EXCEPTION_KEY,
      text: s__('SecurityOrchestration|No exceptions'),
    },
  ],
  name: 'DenyAllowListExceptions',
  components: {
    GlCollapsibleListbox,
    GlFormTextarea,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    exceptionType: {
      type: String,
      required: false,
      default: NO_EXCEPTION_KEY,
    },
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      parsedExceptions: this.exceptions,
      parsedWithErrorsExceptions: findItemsWithErrors(this.exceptions, 'value', 'file'),
    };
  },
  computed: {
    withExceptions() {
      return this.exceptionType === EXCEPTION_KEY;
    },
    toggleText() {
      return EXCEPTION_TYPE_ITEMS.find(({ value }) => value === this.exceptionType).text;
    },
    convertedToStringPackages() {
      return mapObjectsToString(this.parsedExceptions, 'file');
    },
    hasDuplicates() {
      const items = new Set(this.splitItems(this.convertedToStringPackages));
      return items.size < this.parsedExceptions.length;
    },
    hasValidationError() {
      return this.parsedWithErrorsExceptions.length;
    },
    errorMessage() {
      return sprintf(this.$options.i18n.errorMessage, {
        exceptions: this.parsedWithErrorsExceptions.join(' '),
      });
    },
  },
  created() {
    this.debouncedSetExceptions = debounce(this.parsePackages, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSetExceptions.cancel();
  },
  methods: {
    parsePackages(packages) {
      this.parsedExceptions = this.splitItems(packages).map((item) => {
        const [file = '', fullPath = ''] = item.split('@');

        return {
          file,
          fullPath,
          value: item,
        };
      });

      this.parsedWithErrorsExceptions = findItemsWithErrors(this.parsedExceptions, 'value', 'file');

      this.$emit('input', this.parsedExceptions);
    },
    splitItems(items) {
      return items?.split(/[ ,]+/).filter(Boolean) || [];
    },
    selectExceptionType(type) {
      this.$emit('select-exception-type', type);
    },
  },
};
</script>

<template>
  <div>
    <gl-collapsible-listbox
      :disabled="disabled"
      size="small"
      :items="$options.EXCEPTION_TYPE_ITEMS"
      :toggle-text="toggleText"
      :selected="exceptionType"
      @select="selectExceptionType"
    />

    <div v-if="withExceptions" class="gl-mt-4">
      <gl-form-textarea
        no-resize
        :value="convertedToStringPackages"
        @input="debouncedSetExceptions"
      />

      <p
        v-if="hasDuplicates"
        data-testid="error-duplicates-message"
        class="gl-my-2 gl-text-red-500"
      >
        {{ $options.i18n.duplicatesError }}
      </p>

      <p
        v-if="hasValidationError"
        data-testid="error-validation-message"
        class="gl-my-2 gl-text-red-500"
      >
        {{ errorMessage }}
      </p>

      <p class="gl-mt-3">{{ $options.i18n.exceptionMessage }}</p>
    </div>
  </div>
</template>
