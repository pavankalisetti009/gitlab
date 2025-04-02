import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlForm, GlFormInput } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemCustomFieldNumber from 'ee/work_items/components/work_item_custom_fields_number.vue';
import { newWorkItemId } from '~/work_items/utils';
import { CUSTOM_FIELDS_TYPE_NUMBER, CUSTOM_FIELDS_TYPE_TEXT } from '~/work_items/constants';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import { customFieldsWidgetResponseFactory } from 'jest/work_items/mock_data';

describe('WorkItemCustomFieldsNumber', () => {
  let wrapper;

  Vue.use(VueApollo);

  const defaultWorkItemType = 'Task';
  const defaultWorkItemId = 'gid://gitlab/WorkItem/1';

  const defaultField = {
    customField: {
      id: '1-number',
      fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
      name: 'Number custom field label',
    },
    value: 5,
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

  const findComponent = () => wrapper.findComponent(WorkItemCustomFieldNumber);
  const findHeader = () => wrapper.find('h3');
  const findEditButton = () => wrapper.find('[data-testid="edit-number"]');
  const findApplyButton = () => wrapper.find('[data-testid="apply-number"]');
  const findLabel = () => wrapper.find('label');
  const findForm = () => wrapper.findComponent(GlForm);
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findValue = () => wrapper.find('[data-testid="custom-field-value"]');

  const createComponent = ({
    canUpdate = true,
    workItemType = defaultWorkItemType,
    workItemId = defaultWorkItemId,
    customField = defaultField,
    mutationHandler = mutationSuccessHandler,
  } = {}) => {
    wrapper = shallowMount(WorkItemCustomFieldNumber, {
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
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: 'Sample text',
        },
      });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findHeader().exists()).toBe(false);
    });
  });

  describe('label', () => {
    it('shows header when not editing', () => {
      createComponent();

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
    it('shows value when number is set', () => {
      createComponent();

      expect(findValue().text()).toContain('5');
    });

    it('shows None when no number is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-number',
            fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
            name: 'Number custom field label',
          },
          value: null,
        },
      });

      expect(findValue().text()).toContain('None');
    });

    it('shows None when invalid value type is received', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-number',
            fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
            name: 'Number custom field label',
          },
          value: 'Text',
        },
      });

      expect(findValue().text()).toContain('None');
    });
  });

  describe('form and input', () => {
    it('is not shown while not editing', () => {
      createComponent();

      expect(findForm().exists()).toBe(false);
    });

    it('is shown while editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findForm().exists()).toBe(true);
    });

    it('input element is not shown while not editing', () => {
      createComponent();

      expect(findInput().exists()).toBe(false);
    });

    it('input has number-y attributes', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findInput().attributes()).toEqual(
        expect.objectContaining({
          min: '0',
          type: 'number',
        }),
      );
    });
  });

  describe('updating the value', () => {
    it('does not call "workItemUpdate" mutation when option is selected if is create flow', async () => {
      createComponent({ workItemId: newWorkItemId(defaultWorkItemType) });
      await nextTick();

      const newValue = '10';

      await findEditButton().vm.$emit('click');
      findInput().vm.$emit('input', newValue);
      findInput().vm.$emit('blur');

      await waitForPromises();

      expect(mutationSuccessHandler).not.toHaveBeenCalled();
    });

    it('sends mutation with correct variables when updating number', async () => {
      createComponent();
      await nextTick();

      const newValue = '10';

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
              numberValue: 10,
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
              numberValue: null,
            },
          ],
        },
      });
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
      findInput().vm.$emit('input', '10');
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
      findInput().vm.$emit('input', '200');
      findInput().vm.$emit('blur');

      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });
});
