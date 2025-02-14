import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import WorkItemCustomFields from 'ee/work_items/components/work_item_custom_fields.vue';
import WorkItemCustomFieldNumber from 'ee/work_items/components/work_item_custom_fields_number.vue';
import WorkItemCustomFieldText from 'ee/work_items/components/work_item_custom_fields_text.vue';
import WorkItemCustomFieldSingleSelect from 'ee/work_items/components/work_item_custom_fields_single_select.vue';
import WorkItemCustomFieldMultiSelect from 'ee/work_items/components/work_item_custom_fields_multi_select.vue';
import { workItemResponseFactory } from 'jest/work_items/mock_data';
import {
  CUSTOM_FIELDS_TYPE_NUMBER,
  CUSTOM_FIELDS_TYPE_TEXT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
} from '~/work_items/constants';
import workItemCustomFieldsQuery from 'ee/work_items/graphql/work_item_custom_fields.query.graphql';

describe('WorkItemCustomFields', () => {
  let wrapper;

  Vue.use(VueApollo);

  const workItemQueryResponse = ({ customFieldValues } = {}) =>
    workItemResponseFactory({
      customFieldsWidgetPresent: true,
      customFieldValues,
    });

  const successHandler = jest.fn().mockResolvedValue(workItemQueryResponse());
  const emptyCustomFieldsHandler = jest
    .fn()
    .mockResolvedValue(workItemQueryResponse({ customFieldValues: [] }));
  const invalidCustomFieldHandler = jest.fn().mockResolvedValue({
    customFieldValues: [
      {
        id: 'gwid://gitlab/CustomFieldValue/1',
        customField: {
          id: '1-invalid',
          fieldType: 'INVALID_TYPE',
          name: 'Invalid custom field label',
        },
        value: 5,
        __typename: 'LocalWorkItemNumberFieldValue',
      },
    ],
  });
  const errorHandler = jest.fn().mockRejectedValue(new Error('Fetching failed'));

  const createComponent = ({ handler = successHandler } = {}) => {
    wrapper = shallowMount(WorkItemCustomFields, {
      apolloProvider: createMockApollo([[workItemCustomFieldsQuery, handler]]),
      propsData: {
        workItemId: 'gid://gitlab/WorkItem/1',
        workItemType: 'Issue',
        fullPath: 'group/project',
        canUpdate: true,
      },
    });
  };

  const findCustomFieldsComponent = () => wrapper.findComponent(WorkItemCustomFields);
  const findNumberCustomField = () => wrapper.findComponent(WorkItemCustomFieldNumber);
  const findTextCustomField = () => wrapper.findComponent(WorkItemCustomFieldText);
  const findSingleSelectCustomField = () => wrapper.findComponent(WorkItemCustomFieldSingleSelect);
  const findMultiSelectCustomField = () => wrapper.findComponent(WorkItemCustomFieldMultiSelect);

  it('renders custom field component', async () => {
    createComponent();
    await waitForPromises();

    expect(findCustomFieldsComponent().exists()).toBe(true);
  });

  describe('when fields are loaded successfully', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders all custom field types', () => {
      expect(findCustomFieldsComponent().exists()).toBe(true);
      expect(findNumberCustomField().exists()).toBe(true);
      expect(findTextCustomField().exists()).toBe(true);
      expect(findSingleSelectCustomField().exists()).toBe(true);
      expect(findMultiSelectCustomField().exists()).toBe(true);
    });

    it('passes correct props to number field', () => {
      const numberField = findNumberCustomField();
      expect(numberField.props('customField')).toMatchObject({
        customField: {
          id: '1-number',
          fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
          name: 'Number custom field label',
        },
        value: 5,
      });
    });

    it('passes correct props to text field', () => {
      const textField = findTextCustomField();
      expect(textField.props('customField')).toMatchObject({
        customField: {
          id: '1-text',
          fieldType: CUSTOM_FIELDS_TYPE_TEXT,
          name: 'Text custom field label',
        },
        value: 'Sample text',
      });
    });

    it('passes correct props to single select field', () => {
      const selectField = findSingleSelectCustomField();
      expect(selectField.props('customField')).toMatchObject({
        customField: {
          fieldType: CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
          selectOptions: expect.arrayContaining([
            expect.objectContaining({ id: expect.any(String), value: expect.any(String) }),
          ]),
        },
      });
    });

    it('passes correct props to multi select field', () => {
      const multiSelectField = findMultiSelectCustomField();
      expect(multiSelectField.props('customField')).toMatchObject({
        customField: {
          fieldType: CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          selectOptions: expect.arrayContaining([
            expect.objectContaining({ id: expect.any(String), value: expect.any(String) }),
          ]),
        },
      });
    });
  });

  it('does not render custom field component if array is empty', async () => {
    createComponent({ handler: emptyCustomFieldsHandler });
    await waitForPromises();

    expect(wrapper.find('work-item-custom-field').exists()).toBe(false);
  });

  it('throws error if an invalid custom field type is received', async () => {
    jest.spyOn(Sentry, 'captureException');
    const error = new Error('Unknown custom field type: INVALID_TYPE');

    createComponent({ handler: invalidCustomFieldHandler });
    await waitForPromises();

    expect(findCustomFieldsComponent().exists()).toBe(true);
    expect(Sentry.captureException).toHaveBeenCalledWith(error);
  });

  it('shows error alert if fetching custom fields fails', async () => {
    jest.spyOn(Sentry, 'captureException');

    createComponent({ handler: errorHandler });
    await waitForPromises();

    expect(wrapper.emitted('error')).toEqual([
      ['Some fields could not be loaded. Refresh the page to try again.'],
    ]);
    expect(Sentry.captureException).toHaveBeenCalled();
  });
});
