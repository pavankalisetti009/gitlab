<script>
import { GlIcon, GlTruncate } from '@gitlab/ui';
import { GL_DARK } from '~/constants';
import { getSystemColorScheme } from '~/lib/utils/css_utils';
import { STATUS_LIGHT_TO_DARK_COLOR_MAP } from '../../constants';

export default {
  components: {
    GlIcon,
    GlTruncate,
  },
  props: {
    item: {
      type: Object,
      required: true,
      default: () => ({
        name: '',
        iconName: '',
        color: '',
      }),
      validator: (value) => {
        return (
          typeof value.name === 'string' &&
          typeof value.iconName === 'string' &&
          (value.color === undefined || typeof value.color === 'string')
        );
      },
    },
  },
  computed: {
    colorStyle() {
      const color =
        getSystemColorScheme() === GL_DARK
          ? STATUS_LIGHT_TO_DARK_COLOR_MAP[this.item.color] ?? this.item.color
          : this.item.color;
      return this.item.color ? { color } : {};
    },
  },
};
</script>

<template>
  <div
    class="work-item-status gl-inline-flex gl-max-w-full gl-items-center gl-rounded-pill gl-bg-strong gl-py-1 gl-pl-2 gl-pr-[.375rem] gl-text-sm gl-leading-normal gl-text-strong"
    data-testid="work-item-status"
    :aria-label="item.name"
  >
    <gl-icon class="gl-shrink-0" :size="12" :name="item.iconName" :style="colorStyle" />
    <div class="gl-shrink-1 gl-ml-2 gl-min-w-0 gl-overflow-hidden">
      <gl-truncate :text="item.name" with-tooltip />
    </div>
  </div>
</template>
