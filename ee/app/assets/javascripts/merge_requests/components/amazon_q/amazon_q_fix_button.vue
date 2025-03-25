<script>
import { GlAlert, GlButton, GlTooltipDirective } from '@gitlab/ui';

import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';

// REVIEW_FINDING_KEYWORDS is used by ee/app/services/ai/amazon_q/amazon_q_trigger_service.rb
// to determined if the service should be triggered, this needs to be kept in sync with the service.

// eslint-disable-next-line @gitlab/require-i18n-strings
const REVIEW_FINDING_KEYWORDS = ['We detected', 'We recommend', 'Severity:'];
const REVIEW_FINDING_REGEX = new RegExp(REVIEW_FINDING_KEYWORDS.join('|'), 'i');

export default {
  name: 'AmazonQFixButton',
  components: {
    GlButton,
    GlAlert,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    note: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      loading: false,
      alert: null,
    };
  },
  computed: {
    amazonQQuickActionsPath() {
      return this.note.amazon_q_quick_actions_path;
    },
    hasSuggestion() {
      const { note: text } = this.note;
      if (typeof text === 'string') {
        return Boolean(text.match(REVIEW_FINDING_REGEX));
      }
      return false;
    },
  },
  methods: {
    async onClick() {
      this.loading = true;
      try {
        await axios.post(this.amazonQQuickActionsPath, { note_id: this.note.id, command: 'fix' });
      } catch {
        this.alert = {
          variant: 'danger',
          message: s__('AmazonQ|An error occurred. Please try again later.'),
        };
      } finally {
        this.loading = false;
      }
    },
    onAlertDismiss() {
      this.alert = null;
    },
  },
};
</script>

<template>
  <div v-if="amazonQQuickActionsPath && hasSuggestion">
    <gl-alert
      v-if="alert"
      class="gl-mb-3"
      :variant="alert.variant"
      :dismissible="true"
      @dismiss="onAlertDismiss"
    >
      {{ alert.message }}
    </gl-alert>

    <gl-button
      v-gl-tooltip="
        loading
          ? ''
          : s__('AmazonQ|Ask GitLab Duo with Amazon Q to suggest a solution for this issue')
      "
      :loading="loading"
      icon="tanuki-ai"
      @click="onClick"
    >
      {{ s__('AmazonQ|Suggest a fix') }}
    </gl-button>
  </div>
</template>
