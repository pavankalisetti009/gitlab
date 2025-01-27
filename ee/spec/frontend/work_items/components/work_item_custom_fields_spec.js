import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import WorkItemCustomFields from 'ee/work_items/components/work_item_custom_fields.vue';
import WorkItemCustomFieldNumber from 'ee/work_items/components/work_item_custom_fields_number.vue';
import WorkItemCustomFieldText from 'ee/work_items/components/work_item_custom_fields_text.vue';
import { CUSTOM_FIELDS_TYPE_NUMBER, CUSTOM_FIELDS_TYPE_TEXT } from '~/work_items/constants';

const mockCustomFields = [
  {
    id: 'gid://gitlab/CustomFieldValue/1',
    customField: {
      id: '1-number',
      fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
      name: 'Number custom field label',
    },
    value: 5,
  },
  {
    id: 'gid://gitlab/CustomFieldValue/2',
    customField: {
      id: '1-text',
      fieldType: CUSTOM_FIELDS_TYPE_TEXT,
      name: 'Text custom field label',
    },
    value: 'Sample text',
  },
];

describe('WorkItemCustomFields', () => {
  let wrapper;
  const createComponent = (customFields) => {
    wrapper = shallowMount(WorkItemCustomFields, {
      propsData: {
        customFieldValues: customFields,
        workItemType: 'Issue',
        fullPath: 'group/project',
        canUpdate: true,
      },
    });
  };

  const findCustomFieldsComponent = () => wrapper.findComponent(WorkItemCustomFields);
  const findNumberCustomField = () => wrapper.findComponent(WorkItemCustomFieldNumber);
  const findTextCustomField = () => wrapper.findComponent(WorkItemCustomFieldText);

  it('renders custom field component', () => {
    createComponent(mockCustomFields);

    expect(findCustomFieldsComponent().exists()).toBe(true);
  });

  it('does not render custom field component if array is empty', () => {
    createComponent([]);
    expect(wrapper.find('work-item-custom-field').exists()).toBe(false);
  });

  it('renders number field correctly', () => {
    createComponent([mockCustomFields[0]]);
    expect(findCustomFieldsComponent().exists()).toBe(true);
    expect(findNumberCustomField().exists()).toBe(true);
  });

  it('renders text field correctly', () => {
    createComponent([mockCustomFields[1]]);

    expect(findCustomFieldsComponent().exists()).toBe(true);
    expect(findTextCustomField().exists()).toBe(true);
  });

  it('throws error if an invalid custom field type is received', () => {
    jest.spyOn(Sentry, 'captureException');
    const error = new Error('Unknown custom field type: INVALID_TYPE');

    const invalidCustomField = {
      customField: {
        id: '1-invalid',
        fieldType: 'INVALID_TYPE',
        name: 'Invalid custom field label',
      },
    };
    createComponent([invalidCustomField]);

    expect(findCustomFieldsComponent().exists()).toBe(true);
    expect(Sentry.captureException).toHaveBeenCalledWith(error, { extra: invalidCustomField });
  });
});
