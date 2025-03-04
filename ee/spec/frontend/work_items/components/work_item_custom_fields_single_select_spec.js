import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import WorkItemCustomFieldsSingleSelect from 'ee/work_items/components/work_item_custom_fields_single_select.vue';
import {
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
  CUSTOM_FIELDS_TYPE_NUMBER,
} from '~/work_items/constants';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import { customFieldsWidgetResponseFactory } from 'jest/work_items/mock_data';

describe('WorkItemCustomFieldsSingleSelect', () => {
  let wrapper;

  Vue.use(VueApollo);

  const defaultWorkItemType = 'Issue';
  const defaultWorkItemId = 'gid://gitlab/WorkItem/1';

  const defaultField = {
    customField: {
      id: '1-select',
      fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
      name: 'Single select custom field label',
      selectOptions: [
        {
          id: 'select-1',
          value: 'Option 1',
        },
        {
          id: 'select-2',
          value: 'Option 2',
        },
        {
          id: 'select-3',
          value: 'Option 3',
        },
      ],
    },
    selectedOptions: [
      {
        id: 'select-1',
        value: 'Option 1',
      },
    ],
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

  const findComponent = () => wrapper.findComponent(WorkItemCustomFieldsSingleSelect);
  const findSidebarDropdownWidget = () => wrapper.findComponent(WorkItemSidebarDropdownWidget);

  const createComponent = ({
    canUpdate = true,
    workItemType = defaultWorkItemType,
    customField = defaultField,
    workItemId = defaultWorkItemId,
    mutationHandler = mutationSuccessHandler,
  } = {}) => {
    wrapper = shallowMount(WorkItemCustomFieldsSingleSelect, {
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
      expect(findSidebarDropdownWidget().exists()).toBe(true);
    });

    it('does not render if custom field is empty', async () => {
      createComponent({ customField: {} });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(false);
    });

    it('does not render if custom field type is incorrect', async () => {
      createComponent({
        customField: {
          id: '1-number',
          fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
          name: 'Number custom field label',
          selectOptions: null,
        },
        value: 5,
      });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(false);
    });
  });

  it('displays correct label', () => {
    createComponent();

    expect(findSidebarDropdownWidget().props('dropdownLabel')).toBe(
      'Single select custom field label',
    );
  });

  describe('value', () => {
    it('shows None when no option is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            name: 'Single select custom field label',
            selectOptions: [
              {
                id: 'select-1',
                value: 'Option 1',
              },
              {
                id: 'select-2',
                value: 'Option 2',
              },
              {
                id: 'select-3',
                value: 'Option 3',
              },
            ],
          },
          value: null,
        },
      });

      expect(findSidebarDropdownWidget().props().toggleDropdownText).toContain('None');
    });

    it('shows None when invalid value is received', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            name: 'Single select custom field label',
            selectOptions: [
              {
                id: 'select-1',
                value: 'Option 1',
              },
              {
                id: 'select-2',
                value: 'Option 2',
              },
              {
                id: 'select-3',
                value: 'Option 3',
              },
            ],
          },
          value: 'Sample text',
        },
      });

      expect(findSidebarDropdownWidget().props().toggleDropdownText).toContain('None');
    });

    it('shows option selected when is set', () => {
      createComponent();

      expect(findSidebarDropdownWidget().props().toggleDropdownText).toContain('Option 1');
    });
  });

  describe('Dropdown options', () => {
    it('shows selected option on value when dropdown is open', () => {
      createComponent();

      expect(findSidebarDropdownWidget().props('toggleDropdownText')).toBe('Option 1');
      expect(findSidebarDropdownWidget().props('itemValue')).toBe('select-1');
    });

    it('shows "None" on value when dropdown is open and no option was selected', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            name: 'Single select custom field label',
            selectOptions: [
              {
                id: 'select-1',
                value: 'Option 1',
              },
              {
                id: 'select-2',
                value: 'Option 2',
              },
              {
                id: 'select-3',
                value: 'Option 3',
              },
            ],
          },
          value: null,
        },
      });

      expect(findSidebarDropdownWidget().props('toggleDropdownText')).toBe('None');
    });

    it('shows dropdown options on list according to their state', () => {
      createComponent();

      expect(findSidebarDropdownWidget().props('listItems')).toEqual([
        { options: [{ text: 'Option 1', value: 'select-1' }], text: 'Selected' },
        {
          options: [
            { text: 'Option 2', value: 'select-2' },
            { text: 'Option 3', value: 'select-3' },
          ],
          text: 'All',
          textSrOnly: true,
        },
      ]);
    });
  });

  describe('updating the selection', () => {
    it('sends mutation with correct variables when selecting an option', async () => {
      createComponent();
      await nextTick();

      const newSelectedId = 'select-2';
      findSidebarDropdownWidget().vm.$emit('updateValue', newSelectedId);
      await nextTick();

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: {
            customFieldId: defaultField.customField.id,
            selectedOptionIds: [newSelectedId],
          },
        },
      });
    });

    it('sends null when clearing the selection', async () => {
      createComponent();
      await nextTick();

      findSidebarDropdownWidget().vm.$emit('updateValue', null);

      await waitForPromises();

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: {
            customFieldId: defaultField.customField.id,
            selectedOptionIds: [null],
          },
        },
      });
    });

    it('shows loading state while updating', async () => {
      const mutationHandler = jest.fn().mockImplementation(() => new Promise(() => {}));

      createComponent({ mutationHandler });
      await nextTick();

      findSidebarDropdownWidget().vm.$emit('updateValue', 'select-2');
      await nextTick();

      expect(findSidebarDropdownWidget().props('updateInProgress')).toBe(true);
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

      findSidebarDropdownWidget().vm.$emit('updateValue', 'select-2');

      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the issue. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });

    it('emits error event when mutation catches error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorHandler = jest.fn().mockRejectedValue(new Error());

      createComponent({ mutationHandler: errorHandler });
      await nextTick();

      findSidebarDropdownWidget().vm.$emit('updateValue', 'select-2');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the issue. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });
});
