<script>
export default {
  name: 'ComplianceViolationDetailsApp',
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    violationId: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <div>{{ projectPath }} {{ violationId }}</div>
</template>
