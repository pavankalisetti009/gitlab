<script>
import { GlAvatar, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { __, sprintf } from '~/locale';

export default {
  name: 'NamespaceMetadata',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAvatar,
    GlIcon,
  },
  props: {
    data: {
      type: Object,
      required: true,
      validator: (value) =>
        [
          'fullName',
          'id',
          'namespaceType',
          'namespaceTypeIcon',
          'visibilityLevelIcon',
          'visibilityLevelTooltip',
        ].every((key) => value[key]),
    },
  },
  computed: {
    namespaceFullName() {
      return this.data.fullName;
    },
    avatarAltText() {
      return sprintf(__("%{name}'s avatar"), { name: this.namespaceFullName });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-gap-3">
    <gl-avatar
      shape="rect"
      :src="data.avatarUrl"
      :size="48"
      :entity-name="namespaceFullName"
      :entity-id="data.id"
      :fallback-on-error="true"
      :alt="avatarAltText"
    />

    <div class="gl-leading-20">
      <div class="gl-mb-2 gl-flex gl-items-center gl-gap-2">
        <gl-icon
          data-testid="namespace-metadata-namespace-type-icon"
          variant="subtle"
          :name="data.namespaceTypeIcon"
        />
        <span class="gl-text-base gl-font-normal gl-text-subtle">{{ data.namespaceType }}</span>
      </div>
      <div class="gl-flex gl-items-center gl-gap-2">
        <span class="gl-truncate-end gl-text-size-h2 gl-font-bold gl-text-strong">{{
          namespaceFullName
        }}</span>
        <gl-icon
          v-gl-tooltip.viewport
          data-testid="namespace-metadata-visibility-icon"
          variant="subtle"
          :name="data.visibilityLevelIcon"
          :title="data.visibilityLevelTooltip"
        />
      </div>
    </div>
  </div>
</template>
