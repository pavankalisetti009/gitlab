<script>
export default {
  name: 'FeatureSettingsApp',
};
</script>
<template>
  <section>
    <h1 class="page-title gl-text-size-h-display">
      {{ s__('AdminAIPoweredFeatures|AI-powered features') }}
    </h1>
    <div class="gl-items-top gl-flex gl-justify-between">
      <p>
        {{
          s__(
            'AdminAIPoweredFeatures|Features that can be enabled, disabled, or linked to a cloud-based or self-hosted model.',
          )
        }}
      </p>
    </div>
  </section>
</template>
