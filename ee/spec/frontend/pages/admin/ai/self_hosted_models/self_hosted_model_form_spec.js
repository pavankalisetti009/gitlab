import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlForm, GlCollapsibleListbox } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SelfHostedModelForm from 'ee/pages/admin/ai/self_hosted_models/components/self_hosted_model_form.vue';
import InputCopyToggleVisibility from '~/vue_shared/components/form/input_copy_toggle_visibility.vue';
import createSelfHostedModelMutation from 'ee/pages/admin/ai/self_hosted_models/graphql/mutations/create_self_hosted_model.mutation.graphql';
import updateSelfHostedModelMutation from 'ee/pages/admin/ai/self_hosted_models/graphql/mutations/update_self_hosted_model.mutation.graphql';
import { createAlert } from '~/alert';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { SELF_HOSTED_MODEL_MUTATIONS } from 'ee/pages/admin/ai/self_hosted_models/constants';
import { SELF_HOSTED_MODEL_OPTIONS, mockSelfHostedModel as mockModelData } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility');

describe('SelfHostedModelForm', () => {
  let wrapper;

  const basePath = '/admin/ai/self_hosted_models';
  const createMutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModelCreate: {
        errors: [],
      },
    },
  });

  const createComponent = async ({
    props = {
      mutationData: {
        name: SELF_HOSTED_MODEL_MUTATIONS.CREATE,
        mutation: createSelfHostedModelMutation,
      },
    },
    apolloHandlers = [[createSelfHostedModelMutation, createMutationSuccessHandler]],
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = mountExtended(SelfHostedModelForm, {
      apolloProvider: mockApollo,
      provide: {
        basePath,
        modelOptions: SELF_HOSTED_MODEL_OPTIONS,
      },
      propsData: {
        ...props,
      },
    });

    await waitForPromises();
  };

  beforeEach(async () => {
    await createComponent({
      props: {
        mutationData: {
          name: SELF_HOSTED_MODEL_MUTATIONS.CREATE,
          mutation: createSelfHostedModelMutation,
        },
      },
    });
  });

  const findGlForm = () => wrapper.findComponent(GlForm);
  const findNameInputField = () => wrapper.findByLabelText('Deployment name', { exact: false });
  const findEndpointInputField = () => wrapper.findByLabelText('Endpoint', { exact: false });
  const findIdentifierInputField = () =>
    wrapper.findByLabelText('Model identifier', { exact: false });
  const findApiKeyInputField = () => wrapper.findComponent(InputCopyToggleVisibility);
  const findCollapsibleListBox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCreateButton = () => wrapper.find('button[type="submit"]');
  const findCancelButton = () => wrapper.findByText('Cancel');

  it('renders the self-hosted model details form', () => {
    expect(findGlForm().exists()).toBe(true);
  });

  describe('form fields', () => {
    it('renders the name input field', () => {
      expect(findNameInputField().exists()).toBe(true);
    });

    it('renders a model dropdown selector with model options', () => {
      const modelDropdownSelector = findCollapsibleListBox();

      expect(modelDropdownSelector.props('toggleText')).toEqual('Select model');

      const modelOptions = modelDropdownSelector.props('items');
      expect(modelOptions.map((model) => model.text)).toEqual([
        'CodeGemma',
        'Code-Llama',
        'Codestral',
        'Mistral',
        'Deepseek Coder',
        'LLaMA 3',
      ]);
    });

    it('renders the endpoint input field', () => {
      expect(findEndpointInputField().exists()).toBe(true);
    });

    it('renders the optional API token input field', () => {
      expect(findApiKeyInputField().exists()).toBe(true);
    });
  });

  it('renders a cancel button', () => {
    expect(findCancelButton().exists()).toBe(true);
  });

  describe('when required form inputs are missing', () => {
    it('does not invoke mutation', async () => {
      wrapper.find('form').trigger('submit.prevent');

      await waitForPromises();

      expect(createMutationSuccessHandler).not.toHaveBeenCalled();
    });
  });

  describe('server errors', () => {
    describe('when deployment name is not unique', () => {
      const createMutationValidationErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModelCreate: {
            errors: ['Validation failed: Name has already been taken'],
          },
        },
      });
      const apolloHandlers = [
        [createSelfHostedModelMutation, createMutationValidationErrorHandler],
      ];

      beforeEach(async () => {
        await createComponent({ apolloHandlers });
      });

      it('renders an error message', async () => {
        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('http://test.com');
        await findCollapsibleListBox().vm.$emit('select', 'MISTRAL');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(wrapper.text()).toMatch('Please enter a unique deployment name.');
      });
    });

    describe('when endpoint is not valid', () => {
      const createMutationValidationErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModelCreate: {
            errors: [
              'Validation failed: Endpoint is blocked: Only allowed schemes are http, https',
            ],
          },
        },
      });
      const apolloHandlers = [
        [createSelfHostedModelMutation, createMutationValidationErrorHandler],
      ];

      beforeEach(async () => {
        await createComponent({ apolloHandlers });
      });

      it('renders an error message', async () => {
        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('invalid endpoint');
        await findCollapsibleListBox().vm.$emit('select', 'MISTRAL');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(wrapper.text()).toMatch('Please add a valid endpoint.');
      });
    });

    describe('when the error is not specific', () => {
      it('displays a generic error alert', async () => {
        const error = new Error();
        const createMutationErrorHandler = jest.fn().mockRejectedValue(error);

        await createComponent({
          apolloHandlers: [[createSelfHostedModelMutation, createMutationErrorHandler]],
        });

        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('http://test.com');
        await findCollapsibleListBox().vm.$emit('select', 'MISTRAL');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'There was an error saving the self-hosted model. Please try again.',
            error,
            captureError: true,
          }),
        );
      });
    });
  });

  describe('When creating a self-hosted model', () => {
    beforeEach(async () => {
      await findNameInputField().setValue('test deployment');
      await findEndpointInputField().setValue('http://test.com');
      await findCollapsibleListBox().vm.$emit('select', 'MISTRAL');
      await findIdentifierInputField().setValue('provider/model-name');

      wrapper.find('form').trigger('submit.prevent');
    });

    it('renders the submit button with the correct text', () => {
      const button = findCreateButton();

      expect(button.text()).toBe('Create self-hosted model');
    });

    it('invokes the create mutation with correct input variables', async () => {
      await waitForPromises();

      expect(createMutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          name: 'test deployment',
          endpoint: 'http://test.com',
          model: 'MISTRAL',
          apiToken: '',
          identifier: 'provider/model-name',
        },
      });
    });

    it('displays success message when model successfully created', async () => {
      await waitForPromises();

      expect(visitUrlWithAlerts).toHaveBeenCalledWith(basePath, [
        expect.objectContaining({
          message: 'The self-hosted model was successfully created.',
          variant: 'success',
        }),
      ]);
    });
  });

  describe('When editing a self-hosted model', () => {
    const updateMutationSuccessHandler = jest.fn().mockResolvedValue({
      data: {
        aiSelfHostedModelUpdate: {
          errors: [],
        },
      },
    });

    beforeEach(async () => {
      await createComponent({
        props: {
          initialFormValues: mockModelData,
          mutationData: {
            name: SELF_HOSTED_MODEL_MUTATIONS.UPDATE,
            mutation: updateSelfHostedModelMutation,
          },
          submitButtonText: 'Edit self-hosted model',
        },
        apolloHandlers: [[updateSelfHostedModelMutation, updateMutationSuccessHandler]],
      });
    });

    it('renders the submit button with the correct text', () => {
      const button = findCreateButton();

      expect(button.text()).toBe('Edit self-hosted model');
    });

    it('invokes the update mutation with correct input variables', async () => {
      await findNameInputField().setValue('test deployment');
      await findEndpointInputField().setValue('http://test.com');
      await findCollapsibleListBox().vm.$emit('select', 'MISTRAL');
      await findApiKeyInputField().vm.$emit('input', 'abc123');
      await findIdentifierInputField().setValue('provider/model-name');

      wrapper.find('form').trigger('submit.prevent');

      await waitForPromises();

      expect(updateMutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: mockModelData.id,
          name: 'test deployment',
          endpoint: 'http://test.com',
          model: 'MISTRAL',
          apiToken: 'abc123',
          identifier: 'provider/model-name',
        },
      });
    });

    it('displays success message when model successfully saved', async () => {
      await findNameInputField().setValue('test deployment');

      wrapper.find('form').trigger('submit.prevent');

      await waitForPromises();

      expect(visitUrlWithAlerts).toHaveBeenCalledWith(basePath, [
        expect.objectContaining({
          message: 'The self-hosted model was successfully saved.',
          variant: 'success',
        }),
      ]);
    });
  });
});
