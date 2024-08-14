<script>
import { GlButton, GlLabel, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';

import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { ROUTE_EDIT_FRAMEWORK, ROUTE_FRAMEWORKS } from '../../constants';

export default {
  name: 'ComplianceFrameworkBadge',
  components: {
    GlLabel,
    GlButton,
    GlPopover,
  },
  props: {
    framework: {
      type: Object,
      required: true,
    },
    showDefault: {
      type: Boolean,
      required: false,
      default: true,
    },
    showPopover: {
      type: Boolean,
      required: false,
      default: true,
    },
    closeable: {
      type: Boolean,
      required: false,
      default: false,
    },
    showEdit: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    showDefaultBadge() {
      return this.showDefault && this.framework.default;
    },
    frameworkName() {
      const maxLength = 30;
      const name =
        this.framework?.name?.length > maxLength
          ? `${this.framework.name.substring(0, maxLength)}...`
          : this.framework.name;
      return this.showDefaultBadge ? `${name} (${this.$options.i18n.default})` : name;
    },
    frameworkTestId() {
      return this.showDefaultBadge
        ? 'compliance-framework-default-label'
        : 'compliance-framework-label';
    },
  },
  methods: {
    editFromPopover() {
      this.$router.push({
        name: ROUTE_EDIT_FRAMEWORK,
        params: { id: getIdFromGraphQLId(this.framework.id) },
      });
    },
    viewFrameworkDetails() {
      this.$router.push({
        name: ROUTE_FRAMEWORKS,
        query: { id: getIdFromGraphQLId(this.framework.id) },
      });
    },
  },
  i18n: {
    default: s__('ComplianceFrameworks|default'),
    edit: s__('ComplianceReport|Edit the framework'),
    viewDetails: s__('ComplianceReport|View the framework details'),
  },
};
</script>
<template>
  <div ref="badge">
    <gl-popover
      v-if="showPopover"
      ref="popover"
      :title="framework.name"
      :target="() => $refs.label"
    >
      <div v-if="framework.description" class="gl-text-left gl-mb-3">
        {{ framework.description }}
      </div>
      <div class="gl-text-left">
        <gl-button
          v-if="showEdit"
          category="secondary"
          size="small"
          variant="confirm"
          class="gl-font-sm"
          @click="editFromPopover"
        >
          {{ $options.i18n.edit }}
        </gl-button>
        <gl-button
          v-else
          category="secondary"
          size="small"
          variant="confirm"
          class="gl-font-sm"
          @click="viewFrameworkDetails"
        >
          {{ $options.i18n.viewDetails }}
        </gl-button>
      </div>
    </gl-popover>
    <span ref="label">
      <gl-label
        :data-testid="frameworkTestId"
        :background-color="framework.color"
        :title="frameworkName"
        :show-close-button="closeable"
        class="gl-md-max-w-26"
        @close="$emit('close')"
      />
    </span>
  </div>
</template>
