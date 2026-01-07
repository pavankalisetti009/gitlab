<script>
import { GlButton } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import {
  testExistingMavenUpstreamWithOverrides,
  testMavenUpstream,
} from 'ee/api/virtual_registries_api';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

export default {
  name: 'TestMavenUpstreamButton',
  components: {
    GlButton,
  },
  inject: {
    groupPath: {
      default: '',
    },
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    url: {
      type: String,
      required: false,
      default: '',
    },
    username: {
      type: String,
      required: false,
      default: '',
    },
    password: {
      type: String,
      required: false,
      default: '',
    },
    upstreamId: {
      type: Number,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      isTesting: false,
    };
  },
  methods: {
    async testUpstream() {
      try {
        const { url, username, password, upstreamId } = this;
        this.isTesting = true;

        let testFn;
        let args = {};
        const defaultArgs = {
          url,
          username,
          password,
        };
        if (upstreamId) {
          testFn = testExistingMavenUpstreamWithOverrides;
          args = {
            ...defaultArgs,
            id: upstreamId,
          };
        } else {
          testFn = testMavenUpstream;
          args = {
            ...defaultArgs,
            id: this.groupPath,
          };
        }

        const { data } = await testFn(args);

        if (data.success) {
          this.$toast.show(s__('VirtualRegistry|Connection successful.'));
        } else {
          this.$toast.show(
            sprintf(s__('VirtualRegistry|Failed to connect %{msg}'), { msg: data.result }),
          );
        }
      } catch (error) {
        if (error.response?.status === 400 && typeof error.response?.data?.message === 'object') {
          const message = Object.entries(error.response.data.message)[0].join(' ');
          this.$toast.show(
            sprintf(s__('VirtualRegistry|Failed to connect %{msg}'), { msg: message }),
          );
        } else {
          this.$toast.show(s__('VirtualRegistry|Failed to connect.'));
          captureException({ error, name: this.$options.name });
        }
      } finally {
        this.isTesting = false;
      }
    },
  },
};
</script>

<template>
  <gl-button
    :disabled="disabled"
    :loading="isTesting"
    variant="confirm"
    category="tertiary"
    @click="testUpstream"
  >
    {{ s__('VirtualRegistry|Test upstream') }}
  </gl-button>
</template>
