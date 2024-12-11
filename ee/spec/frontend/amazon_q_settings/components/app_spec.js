import { nextTick } from 'vue';
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormInput,
  GlFormInputGroup,
  GlFormGroup,
  GlFormRadioGroup,
  GlFormRadio,
  GlSprintf,
} from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import App from 'ee/amazon_q_settings/components/app.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { createAndSubmitForm } from '~/lib/utils/create_and_submit_form';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

jest.mock('~/lib/utils/create_and_submit_form');

const TEST_SUBMIT_URL = '/foo/submit/url';
const TEST_AMAZON_Q_SETTINGS = {
  ready: true,
  availability: 'default_on',
  roleArn: 'aws:role:arn',
};

describe('ee/amazon_q_settings/components/app.vue', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(App, {
      propsData: {
        submitUrl: TEST_SUBMIT_URL,
        identityProviderPayload: {
          instance_uid: 'instance-uid',
          aws_provider_url: 'https://provider.url',
          aws_audience: 'audience',
        },
        ...props,
      },
      stubs: {
        GlFormInputGroup,
        GlSprintf,
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormGroup = (label) =>
    findForm()
      .findAllComponents(GlFormGroup)
      .wrappers.find((x) => x.attributes('label') === label);

  const findStatusFormGroup = () => findFormGroup('Status');
  const findSetupFormGroup = () => findFormGroup('Setup');
  const listItems = () => findSetupFormGroup().findAll('ol li').wrappers;
  const listItem = (at) => listItems()[at];

  // arn helpers -----
  const findArnFormGroup = () => findFormGroup("IAM role's ARN");
  const findArnField = () => findArnFormGroup().findComponent(GlFormInput);
  const setArn = (val) => findArnField().vm.$emit('input', val);

  // availability helpers -----
  const findAvailabilityRadioGroup = () =>
    findFormGroup('Availability').findComponent(GlFormRadioGroup);
  const findAvailabilityRadioButtons = () =>
    findAvailabilityRadioGroup()
      .findAllComponents(GlFormRadio)
      .wrappers.map((x) => ({
        value: x.attributes('value'),
        label: x.text(),
      }));
  const setAvailability = (val) => findAvailabilityRadioGroup().vm.$emit('input', val);

  // warning helpers -----
  const findAvailabilityWarning = () => findForm().findComponent(GlAlert);
  const findSaveWarning = () => findForm().find('[data-testid=amazon-q-save-warning]');
  const findSaveWarningLink = () => findSaveWarning().find('a');

  // button helpers -----
  const findButton = (text) =>
    findForm()
      .findAllComponents(GlButton)
      .wrappers.find((x) => x.text() === text);
  const findSubmitButton = () => findButton('Save changes');

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders form', () => {
      expect(findForm().exists()).toBe(true);
    });

    it('does not render status', () => {
      expect(findStatusFormGroup()).toBeUndefined();
    });

    describe('setup', () => {
      it('renders setup', () => {
        expect(findSetupFormGroup().exists()).toBe(true);

        expect(listItems()).toHaveLength(3);
      });

      it('renders step 1', () => {
        const idpStepText = listItem(0).text();
        const idpStepHelpPageLink = listItem(0).findComponent(HelpPageLink);

        expect(idpStepText).toBe(
          'Create an identity provider for this GitLab instance within AWS using the following values. Learn more.',
        );
        expect(idpStepHelpPageLink.props()).toEqual({
          anchor: 'create-an-iam-identity-provider',
          href: 'user/duo_amazon_q/setup.md',
        });
        expect(idpStepHelpPageLink.text()).toEqual('Learn more');
      });

      it('renders identity provider details with clipboard buttons', () => {
        const idpFormFields = listItem(0).findAllComponents(GlFormInputGroup).wrappers;
        const idpClipboardButtons = listItem(0).findAllComponents(ClipboardButton).wrappers;

        expect(idpFormFields[0].props('value')).toEqual('instance-uid');
        expect(idpClipboardButtons[0].props('text')).toEqual('instance-uid');

        expect(idpFormFields[1].props('value')).toEqual('OpenID Connect');
        expect(idpClipboardButtons[1].props('text')).toEqual('OpenID Connect');

        expect(idpFormFields[2].props('value')).toEqual('https://provider.url');
        expect(idpClipboardButtons[2].props('text')).toEqual('https://provider.url');

        expect(idpFormFields[3].props('value')).toEqual('audience');
        expect(idpClipboardButtons[3].props('text')).toEqual('audience');
      });

      it('renders step 2', () => {
        const iamStepText = listItem(1).text();
        const iamStepHelpPageLink = listItem(1).findComponent(HelpPageLink);

        expect(iamStepText).toBe(
          'Within your AWS account, create an IAM role for Amazon Q and the relevant identity provider. Learn how to create an IAM role.',
        );
        expect(iamStepHelpPageLink.props()).toEqual({
          anchor: 'create-an-iam-role',
          href: 'user/duo_amazon_q/setup.md',
        });
        expect(iamStepHelpPageLink.text()).toEqual('Learn how to create an IAM role');
      });

      it('renders step 3', () => {
        const arnStepText = listItem(2).text();

        expect(arnStepText).toEqual("Enter the IAM role's ARN.");
      });
    });

    it('renders arn field', () => {
      expect(findArnFormGroup().exists()).toBe(true);

      const input = findArnFormGroup().findComponent(GlFormInput);

      expect(input.attributes()).toMatchObject({
        value: '',
        type: 'text',
        width: 'lg',
        name: 'aws_role',
        placeholder: 'arn:aws:iam::account-id:role/role-name',
      });
    });

    it('renders availability field', () => {
      expect(findAvailabilityRadioGroup().attributes()).toMatchObject({
        checked: 'default_on',
        name: 'availability',
      });
      expect(findAvailabilityRadioButtons()).toEqual([
        {
          label: 'On by default',
          value: 'default_on',
        },
        {
          label: 'Off by default',
          value: 'default_off',
        },
        {
          label: 'Always off',
          value: 'never_on',
        },
      ]);
    });

    it('does not render availability warning', () => {
      expect(findAvailabilityWarning().exists()).toBe(false);
    });

    it('renders enabled arn', () => {
      expect(findArnFormGroup().attributes('disabled')).toBeUndefined();
    });

    it('renders save button', () => {
      expect(findSubmitButton().attributes()).toMatchObject({
        type: 'submit',
        variant: 'confirm',
        category: 'primary',
      });
    });

    it('renders save acknowledgement', () => {
      expect(findSaveWarning().text()).toBe(
        'I understand that by selecting Save changes, GitLab creates a service account for Amazon Q and sends its credentials to AWS. Use of the Amazon Q Developer capabilities as part of GitLab Duo with Amazon Q is governed by the AWS Customer Agreement or other written agreement between you and AWS governing your use of AWS services.',
      );

      expect(findSaveWarningLink().attributes()).toEqual({
        href: 'http://aws.amazon.com/agreement',
        rel: 'noopener noreferrer',
        target: '_blank',
      });
      expect(findSaveWarningLink().text()).toEqual('AWS Customer Agreement');
    });

    describe('when submitting', () => {
      let event;

      beforeEach(async () => {
        event = new Event('submit');
        jest.spyOn(event, 'preventDefault');

        setArn('aws:test:value');
        setAvailability('default_off');

        await nextTick();

        findForm().vm.$emit('submit', event);
      });

      it('prevents default', () => {
        expect(event.preventDefault).toHaveBeenCalled();
      });

      it('triggers submit form', () => {
        expect(createAndSubmitForm).toHaveBeenCalledTimes(1);
        expect(createAndSubmitForm).toHaveBeenCalledWith({
          url: TEST_SUBMIT_URL,
          data: {
            availability: 'default_off',
            role_arn: 'aws:test:value',
          },
        });
      });
    });
  });

  describe('when ready', () => {
    beforeEach(() => {
      createWrapper({
        amazonQSettings: TEST_AMAZON_Q_SETTINGS,
      });
    });

    it('renders status', () => {
      expect(findStatusFormGroup().exists()).toBe(true);
      expect(findStatusFormGroup().text()).toBe(App.I18N_READY);
    });

    it('does not render setup', () => {
      expect(findSetupFormGroup()).toBeUndefined();
    });

    it('renders disabled arn', () => {
      expect(findArnFormGroup().attributes('disabled')).toBeDefined();
    });

    it('does not render save acknowledgement', () => {
      expect(findSaveWarning().exists()).toBe(false);
    });

    describe('when submitting', () => {
      beforeEach(async () => {
        setAvailability('default_off');

        await nextTick();

        findForm().vm.$emit('submit', new Event('submit'));
      });

      it('triggers submit form', () => {
        expect(createAndSubmitForm).toHaveBeenCalledTimes(1);
        expect(createAndSubmitForm).toHaveBeenCalledWith({
          url: TEST_SUBMIT_URL,
          data: {
            availability: 'default_off',
          },
        });
      });
    });
  });

  describe('availability warnings', () => {
    it.each`
      orig             | value            | expected
      ${'default_off'} | ${'default_off'} | ${''}
      ${'default_off'} | ${'never_on'}    | ${App.I18N_WARNING_NEVER_ON}
      ${'default_off'} | ${'default_on'}  | ${''}
      ${'never_on'}    | ${'never_on'}    | ${''}
      ${'never_on'}    | ${'default_off'} | ${App.I18N_WARNING_OFF_BY_DEFAULT}
      ${'never_on'}    | ${'default_on'}  | ${''}
      ${'default_on'}  | ${'default_on'}  | ${''}
      ${'default_on'}  | ${'default_off'} | ${App.I18N_WARNING_OFF_BY_DEFAULT}
      ${'default_on'}  | ${'never_on'}    | ${App.I18N_WARNING_NEVER_ON}
    `('from $orig to $value', async ({ orig, value, expected }) => {
      createWrapper({
        amazonQSettings: {
          ...TEST_AMAZON_Q_SETTINGS,
          availability: orig,
        },
      });

      expect(findAvailabilityWarning().exists()).toBe(false);

      setAvailability(value);
      await nextTick();

      if (expected) {
        expect(findAvailabilityWarning().props()).toMatchObject({
          dismissible: false,
          variant: 'warning',
        });
        expect(findAvailabilityWarning().text()).toBe(expected);
      } else {
        expect(findAvailabilityWarning().exists()).toBe(false);
      }
    });
  });
});
