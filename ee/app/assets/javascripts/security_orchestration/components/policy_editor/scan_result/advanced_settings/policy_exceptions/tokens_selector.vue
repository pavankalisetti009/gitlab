<script>
import { s__ } from '~/locale';

export default {
  i18n: {
    title: s__('ScanResultPolicy|Service accounts/tokens'),
  },
  name: 'TokensSelector',
};
</script>

<template>
  <div>{{ $options.i18n.title }}</div>
</template>
