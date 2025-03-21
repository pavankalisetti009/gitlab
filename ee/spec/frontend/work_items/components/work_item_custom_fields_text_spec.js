import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlForm, GlFormInput, GlLink, GlTruncate, GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemCustomFieldText from 'ee/work_items/components/work_item_custom_fields_text.vue';
import { CUSTOM_FIELDS_TYPE_TEXT, CUSTOM_FIELDS_TYPE_NUMBER } from '~/work_items/constants';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import { customFieldsWidgetResponseFactory } from 'jest/work_items/mock_data';

describe('WorkItemCustomFieldsText', () => {
  let wrapper;

  Vue.use(VueApollo);

  const defaultWorkItemType = 'Task';
  const defaultWorkItemId = 'gid://gitlab/WorkItem/1';

  const defaultField = {
    customField: {
      id: '1-text',
      fieldType: CUSTOM_FIELDS_TYPE_TEXT,
      name: 'Text custom field label',
    },
    value: 'Sample text',
  };

  const mutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      workItemUpdate: {
        workItem: {
          id: defaultWorkItemId,
          widgets: [customFieldsWidgetResponseFactory],
        },
        errors: [],
      },
    },
  });

  const findComponent = () => wrapper.findComponent(WorkItemCustomFieldText);
  const findHeader = () => wrapper.find('h3');
  const findEditButton = () => wrapper.find('[data-testid="edit-text"]');
  const findApplyButton = () => wrapper.find('[data-testid="apply-text"]');
  const findLabel = () => wrapper.find('label');
  const findForm = () => wrapper.findComponent(GlForm);
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findLink = () => wrapper.findComponent(GlLink);
  const findText = () => wrapper.findComponent(GlTruncate);
  const findValue = () => wrapper.find('[data-testid="custom-field-value"]');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  const createComponent = ({
    canUpdate = true,
    workItemType = defaultWorkItemType,
    workItemId = defaultWorkItemId,
    customField = defaultField,
    mutationHandler = mutationSuccessHandler,
  } = {}) => {
    wrapper = shallowMount(WorkItemCustomFieldText, {
      apolloProvider: createMockApollo([[updateWorkItemCustomFieldsMutation, mutationHandler]]),
      propsData: {
        canUpdate,
        customField,
        workItemType,
        workItemId,
      },
    });
  };

  describe('rendering', () => {
    it('renders if custom field exists and type is correct', async () => {
      createComponent();

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findHeader().exists()).toBe(true);
    });

    it('does not render if custom field is empty', async () => {
      createComponent({ customField: {} });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findHeader().exists()).toBe(false);
    });

    it('does not render if custom field type is incorrect', async () => {
      createComponent({
        customField: {
          id: '1-number',
          fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
          name: 'Number custom field label',
        },
        value: 5,
      });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findHeader().exists()).toBe(false);
    });
  });

  describe('label', () => {
    it('shows header when not editing', async () => {
      createComponent();

      await nextTick();

      expect(findHeader().exists()).toBe(true);
      expect(findHeader().classes('gl-sr-only')).toBe(false);
      expect(findLabel().exists()).toBe(false);
    });

    it('shows label and hides header while editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findLabel().exists()).toBe(true);
      expect(findHeader().classes('gl-sr-only')).toBe(true);
    });
  });

  describe('edit button', () => {
    it('is not shown if user cannot edit', () => {
      createComponent({ canUpdate: false });

      expect(findEditButton().exists()).toBe(false);
    });

    it('is shown if user can edit', () => {
      createComponent({ canUpdate: true });

      expect(findEditButton().exists()).toBe(true);
    });

    it('triggers edit mode on click', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findLabel().exists()).toBe(true);
      expect(findForm().exists()).toBe(true);
    });

    it('is replaced by Apply button while editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findEditButton().exists()).toBe(false);
      expect(findApplyButton().exists()).toBe(true);
    });
  });

  describe('value', () => {
    it('shows None when no text is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: null,
        },
      });

      expect(findValue().text()).toContain('None');
    });

    it('shows None when invalid value is received', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: 5,
        },
      });

      expect(findValue().text()).toContain('None');
    });

    it('shows text when text is set', () => {
      createComponent();

      expect(findLink().exists()).toBe(false);
      expect(findText().props().text).toContain('Sample text');
    });

    it('shows link value when link is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/41',
        },
      });

      expect(findLink().exists()).toBe(true);
      expect(findLink().attributes().href).toContain(
        'https://gitlab.com/gitlab-org/gitlab/-/work_items/41',
      );
    });

    it('shows character limit warning', async () => {
      createComponent();
      await nextTick();

      await findEditButton().vm.$emit('click');

      // Generates a string that's > 90% of the CHARACTER_LIMIT
      const longText = 'a'.repeat(1000); // CHARACTER_LIMIT is 1024
      findInput().vm.$emit('input', longText);

      await nextTick();

      const warningText = wrapper.find('.gl-text-subtle');
      expect(warningText.text()).toContain('characters remaining');
    });
  });

  describe('form and input', () => {
    it('is not shown while not editing', () => {
      createComponent();

      expect(findForm().exists()).toBe(false);
    });

    it('shows input while editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findForm().exists()).toBe(true);
    });

    it('does not show input while not editing', () => {
      createComponent();

      expect(findInput().exists()).toBe(false);
    });

    it('input has text-y attributes', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findInput().attributes()).toEqual(
        expect.objectContaining({
          maxlength: '1024',
          placeholder: 'Enter text',
        }),
      );
    });
  });

  describe('updating the value', () => {
    it('sends mutation with correct variables when updating text', async () => {
      createComponent();
      await nextTick();

      const newValue = 'Updated text';

      await findEditButton().vm.$emit('click');
      findInput().vm.$emit('input', newValue);
      findInput().vm.$emit('blur');

      await waitForPromises();

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              textValue: newValue,
            },
          ],
        },
      });
    });

    it('sends null when clearing the field', async () => {
      createComponent();
      await nextTick();

      await findEditButton().vm.$emit('click');
      findInput().vm.$emit('input', '');
      findInput().vm.$emit('blur');

      await waitForPromises();

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              textValue: null,
            },
          ],
        },
      });
    });

    it('shows loading state while updating', async () => {
      const mutationHandler = jest.fn().mockImplementation(() => new Promise(() => {}));

      createComponent({ mutationHandler });
      await nextTick();

      await findEditButton().vm.$emit('click');
      findInput().vm.$emit('input', 'New text');
      findInput().vm.$emit('blur');
      await nextTick();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findInput().attributes('disabled')).toBeDefined();
    });

    it('emits error event when mutation returns an error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorMessage = 'Failed to update';
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemUpdate: {
            errors: [errorMessage],
          },
        },
      });

      createComponent({ mutationHandler });
      await nextTick();

      await findEditButton().vm.$emit('click');
      findInput().vm.$emit('input', 'New text');
      findInput().vm.$emit('blur');

      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });

    it('emits error event when mutation catches error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorHandler = jest.fn().mockRejectedValue(new Error());

      createComponent({ mutationHandler: errorHandler });
      await nextTick();

      await findEditButton().vm.$emit('click');
      findInput().vm.$emit('input', 'New text');
      findInput().vm.$emit('blur');

      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });
});
