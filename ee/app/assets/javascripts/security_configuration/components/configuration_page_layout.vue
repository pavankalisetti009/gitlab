<script>
export default {
  props: {
    noBorder: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>

<template>
  <article>
    <slot name="alert"></slot>
    <header
      class="gl-mt-5 gl-flex gl-justify-between"
      :class="{
        ['gl-mb-5 gl-border-b-1 gl-border-b-gray-100 gl-border-b-solid']: !noBorder,
      }"
    >
      <div class="gl-flex gl-w-full gl-flex-col gl-justify-between md:gl-flex-row">
        <div>
          <h4 class="gl-mt-0">
            <slot name="heading"></slot>
          </h4>
          <p>
            <slot name="description"></slot>
          </p>
        </div>
        <div class="">
          <slot name="actions"></slot>
        </div>
      </div>
    </header>
    <slot></slot>
  </article>
</template>
