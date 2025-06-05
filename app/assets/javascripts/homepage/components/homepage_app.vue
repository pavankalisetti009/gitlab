<script>
import TodosWidget from './todos_widget.vue';

export default {
  components: { TodosWidget },
};
</script>

<template>
  <div>
    <h1>{{ __("Today's highlights") }}</h1>
    <todos-widget />
  </div>
</template>
