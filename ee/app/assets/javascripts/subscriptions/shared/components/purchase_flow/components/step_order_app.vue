<template>
  <div>
    <slot name="alerts"></slot>
    <h2 class="gl-mb-6 gl-mt-0 lg:gl-mx-12">{{ s__('Checkout|Checkout') }}</h2>
    <div class="gl-flex-row gl-flex-nowrap lg:gl-flex">
      <div class="gl-px-0 lg:gl-ml-12 lg:gl-mr-10 lg:gl-w-4/10">
        <slot name="checkout"></slot>
      </div>
      <div class="gl-px-0 lg:gl-ml-10 lg:gl-mr-12 lg:gl-w-3/10">
        <slot name="order-summary"></slot>
      </div>
    </div>
  </div>
</template>
