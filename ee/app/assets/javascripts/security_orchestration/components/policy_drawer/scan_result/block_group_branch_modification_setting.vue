<script>
import { GlSprintf } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { getGroupsById } from '../../policy_editor/scan_result/lib/settings';

export default {
  name: 'BlockGroupBranchModificationSetting',
  i18n: {
    title: s__('SecurityOrchestration|Override the following project settings:'),
    blockGroupBranchModificationExceptions: s__('SecurityOrchestration|exceptions: %{exceptions}'),
  },
  components: {
    GlSprintf,
  },
  props: {
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      exceptionGroups: [],
    };
  },
  computed: {
    exceptionStrings() {
      return this.exceptions.map(({ id }) => {
        const retrievedGroup = this.exceptionGroups.find((group) => group.id === id);
        return retrievedGroup?.full_name || this.getDefaultName(id);
      });
    },
  },
  async mounted() {
    this.exceptionGroups = await getGroupsById(this.exceptions.map(({ id }) => id));
  },
  methods: {
    getDefaultName(id) {
      return sprintf(s__('SecurityOrchestration|Group ID: %{id}'), { id });
    },
  },
};
</script>

<template>
  <div class="gl-ml-5 gl-mt-2">
    <gl-sprintf :message="$options.i18n.blockGroupBranchModificationExceptions">
      <template #exceptions>
        <ul data-testid="group-branch-exceptions">
          <li v-for="exception in exceptionStrings" :key="exception" class="gl-mt-2">
            {{ exception }}
          </li>
        </ul>
      </template>
    </gl-sprintf>
  </div>
</template>
