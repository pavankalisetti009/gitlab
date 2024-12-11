<script>
import {
  GlButton,
  GlAlert,
  GlFormGroup,
  GlFormInput,
  GlFormInputGroup,
  GlForm,
  GlFormRadioGroup,
  GlFormRadio,
  GlSprintf,
  GlModalDirective,
} from '@gitlab/ui';
import { createAndSubmitForm } from '~/lib/utils/create_and_submit_form';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { logError } from '~/lib/logger';
import { createAlert } from '~/alert';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

const AVAILABILITY_OPTIONS = [
  {
    value: 'default_on',
    label: s__('AmazonQ|On by default'),
    helpText: s__(
      'AmazonQ|Features are available. However, any group, subgroup, or project can turn them off.',
    ),
  },
  {
    value: 'default_off',
    label: s__('AmazonQ|Off by default'),
    helpText: s__(
      'AmazonQ|Features are not available. However, any group, subgroup, or project can turn them on.',
    ),
  },
  {
    value: 'never_on',
    label: s__('AmazonQ|Always off'),
    helpText: s__(
      'AmazonQ|Features are not available and cannot be turned on for any group, subgroup, or project.',
    ),
  },
];

export default {
  components: {
    ClipboardButton,
    GlAlert,
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormInputGroup,
    GlFormRadioGroup,
    GlFormRadio,
    GlSprintf,
    HelpPageLink,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  props: {
    submitUrl: {
      type: String,
      required: true,
    },
    identityProviderPayload: {
      type: Object,
      required: false,
      default: null,
    },
    amazonQSettings: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      availability: this.amazonQSettings?.availability || 'default_on',
      roleArn: this.amazonQSettings?.roleArn || '',
      ready: this.amazonQSettings?.ready || false,
      isSubmitting: false,
    };
  },
  computed: {
    payload() {
      if (this.ready) {
        return {
          availability: this.availability,
        };
      }

      return {
        availability: this.availability,
        role_arn: this.roleArn,
      };
    },
    roleArnDisabled() {
      return this.isSubmitting || this.ready;
    },
    availabilityWarning() {
      if (!this.ready || this.availability === this.amazonQSettings?.availability) {
        return '';
      }

      if (this.availability === 'never_on') {
        return this.$options.I18N_WARNING_NEVER_ON;
      }
      if (this.availability === 'default_off') {
        return this.$options.I18N_WARNING_OFF_BY_DEFAULT;
      }
      return '';
    },
    identityProviderFields() {
      return [
        { label: s__('AmazonQ|Instance ID'), value: this.identityProviderPayload.instance_uid },
        { label: s__('AmazonQ|Provider type'), value: 'OpenID Connect' },
        {
          label: s__('AmazonQ|Provider URL'),
          value: this.identityProviderPayload.aws_provider_url,
        },
        { label: s__('AmazonQ|Audience'), value: this.identityProviderPayload.aws_audience },
      ];
    },
  },
  methods: {
    onSubmit() {
      try {
        this.isSubmitting = true;

        createAndSubmitForm({
          url: this.submitUrl,
          data: this.payload,
        });
      } catch (e) {
        // eslint-disable-next-line @gitlab/require-i18n-strings
        logError('Unexpected error while submitting the form.', e);

        createAlert({
          message: s__(
            'AmazonQ|An unexpected error occurred while submitting the form. Please see the browser console log for more details.',
          ),
          error: e,
        });
      } finally {
        this.isSubmitting = false;
      }
    },
  },
  AVAILABILITY_OPTIONS,
  I18N_READY: s__('AmazonQ|GitLab Duo with Amazon Q is ready to go! 🎉'),
  I18N_STEP_IDENTITY_PROVIDER: s__(
    'AmazonQ|Create an identity provider for this GitLab instance within AWS using the following values. %{helpStart}Learn more%{helpEnd}.',
  ),
  I18N_STEP_IAM_ROLE: s__(
    'AmazonQ|Within your AWS account, create an IAM role for Amazon Q and the relevant identity provider. %{helpStart}Learn how to create an IAM role%{helpEnd}.',
  ),
  I18N_IAM_ROLE_ARN_LABEL: s__("AmazonQ|IAM role's ARN"),
  I18N_SAVE_ACKNOWLEDGE: s__(
    'AmazonQ|I understand that by selecting Save changes, GitLab creates a service account for Amazon Q and sends its credentials to AWS. Use of the Amazon Q Developer capabilities as part of GitLab Duo with Amazon Q is governed by the %{helpStart}AWS Customer Agreement%{helpEnd} or other written agreement between you and AWS governing your use of AWS services.',
  ),
  I18N_WARNING_OFF_BY_DEFAULT: s__(
    'AmazonQ|Amazon Q will be turned off by default, but still be available to any groups or projects that have previously enabled it.',
  ),
  I18N_WARNING_NEVER_ON: s__(
    'AmazonQ|Amazon Q will be turned off for all groups, subgroups, and projects, even if they have previously enabled it.',
  ),
  I18N_COPY: s__('AmazonQ|Copy to clipboard'),
  INPUT_PLACEHOLDER_ARN: 'arn:aws:iam::account-id:role/role-name',
  HELP_PAGE_IAM_ROLE: helpPagePath('user/duo_amazon_q/setup.md', {
    anchor: 'create-an-iam-role',
  }),
};
</script>

<template>
  <gl-form @submit.prevent="onSubmit">
    <gl-form-group v-if="ready" :label="s__('AmazonQ|Status')">
      {{ $options.I18N_READY }}
    </gl-form-group>
    <gl-form-group v-else :label="s__('AmazonQ|Setup')">
      <ol class="gl-mb-0 gl-list-inside gl-pl-0">
        <li>
          <gl-sprintf :message="$options.I18N_STEP_IDENTITY_PROVIDER">
            <template #help="{ content }">
              <help-page-link
                href="user/duo_amazon_q/setup.md"
                anchor="create-an-iam-identity-provider"
                target="_blank"
                rel="noopener noreferrer"
                >{{ content }}</help-page-link
              >
            </template>
          </gl-sprintf>
          <div class="gl-mt-3">
            <gl-form-group
              v-for="field in identityProviderFields"
              :key="field.label"
              :label="field.label"
            >
              <gl-form-input-group readonly :value="field.value">
                <template #append>
                  <clipboard-button :text="field.value" :title="$options.I18N_COPY" />
                </template>
              </gl-form-input-group>
            </gl-form-group>
          </div>
        </li>
        <li>
          <gl-sprintf :message="$options.I18N_STEP_IAM_ROLE">
            <template #help="{ content }">
              <help-page-link
                href="user/duo_amazon_q/setup.md"
                anchor="create-an-iam-role"
                target="_blank"
                rel="noopener noreferrer"
                >{{ content }}</help-page-link
              >
            </template>
          </gl-sprintf>
        </li>
        <li>
          {{ s__("AmazonQ|Enter the IAM role's ARN.") }}
        </li>
      </ol>
    </gl-form-group>
    <gl-form-group :label="$options.I18N_IAM_ROLE_ARN_LABEL" :disabled="roleArnDisabled">
      <gl-form-input
        v-model="roleArn"
        type="text"
        width="lg"
        name="aws_role"
        :placeholder="$options.INPUT_PLACEHOLDER_ARN"
      />
    </gl-form-group>
    <gl-form-group class="!gl-mb-3" :label="s__('AmazonQ|Availability')">
      <gl-form-radio-group v-model="availability" name="availability">
        <gl-form-radio
          v-for="{ value, label, helpText } in $options.AVAILABILITY_OPTIONS"
          :key="value"
          :value="value"
        >
          {{ label }}
          <template #help>{{ helpText }}</template>
        </gl-form-radio>
      </gl-form-radio-group>
    </gl-form-group>
    <gl-alert v-if="availabilityWarning" class="gl-mb-5" :dismissible="false" variant="warning">{{
      availabilityWarning
    }}</gl-alert>
    <div class="gl-flex">
      <gl-button type="submit" variant="confirm" category="primary" :loading="isSubmitting">
        {{ s__('AmazonQ|Save changes') }}
      </gl-button>
    </div>
    <p v-if="!ready" class="gl-mt-3" data-testid="amazon-q-save-warning">
      <gl-sprintf :message="$options.I18N_SAVE_ACKNOWLEDGE">
        <template #help="{ content }">
          <a href="http://aws.amazon.com/agreement" target="_blank" rel="noopener noreferrer">{{
            content
          }}</a>
        </template>
      </gl-sprintf>
    </p>
  </gl-form>
</template>
