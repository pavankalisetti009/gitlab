import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import { GlBadge } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TimeagoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import CreateCustomField from 'ee/groups/settings/work_items/create_custom_field.vue';
import CustomFieldsTable from 'ee/groups/settings/work_items/custom_fields_list.vue';
import groupCustomFieldsQuery from 'ee/groups/settings/work_items/group_custom_fields.query.graphql';

Vue.use(VueApollo);

describe('CustomFieldsTable', () => {
  let wrapper;

  const findDetailsButton = () => wrapper.find('[data-testid="toggleDetailsButton"');

  const selectField = {
    id: '1',
    name: 'Test Select Field',
    fieldType: 'SELECT',
    active: true,
    workItemTypes: [{ id: '1', name: 'Issue' }],
    selectOptions: [
      {
        id: 'select-1',
        value: 'value 1',
      },
      {
        id: 'select-2',
        value: 'value 2',
      },
    ],
    updatedAt: '2023-01-01T00:00:00Z',
    createdAt: '2023-01-01T00:00:00Z',
  };

  const stringField = {
    id: '1',
    name: 'Test Text Field',
    fieldType: 'STRING',
    active: true,
    workItemTypes: [
      { id: '1', name: 'Issue' },
      { id: '2', name: 'Task' },
    ],
    selectOptions: [],
    updatedAt: '2023-01-01T00:00:00Z',
    createdAt: '2023-01-01T00:00:00Z',
  };

  const createComponent = ({
    fields = [selectField],
    customFieldsResponse = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '123',
          customFields: {
            nodes: fields,
            count: fields.length,
          },
        },
      },
    }),
  } = {}) => {
    wrapper = mount(CustomFieldsTable, {
      provide: {
        fullPath: 'group/path',
      },
      apolloProvider: createMockApollo([[groupCustomFieldsQuery, customFieldsResponse]]),
      stubs: { GlIntersperse: true },
    });
  };

  it('displays correct count in badge', async () => {
    createComponent();
    await waitForPromises();

    const badge = wrapper.findComponent(GlBadge);
    expect(badge.text()).toBe('1/50');
  });

  it('detailsToggleIcon returns correct icon based on visibility', async () => {
    createComponent();
    await waitForPromises();

    expect(findDetailsButton().props().icon).toBe('chevron-right');

    findDetailsButton().trigger('click');
    await nextTick();

    expect(findDetailsButton().props().icon).toBe('chevron-down');
  });

  it('humanizes field type', async () => {
    createComponent();
    await waitForPromises();

    expect(wrapper.text()).toContain('Select');
  });

  it('selectOptionsText returns correct text based on options length', async () => {
    createComponent();
    await waitForPromises();

    expect(wrapper.text()).toContain('2 options');
  });

  it('lists work item types', async () => {
    createComponent({ fields: [stringField] });
    await waitForPromises();

    expect(wrapper.text()).toContain('Issue');
    expect(wrapper.text()).toContain('Task');
  });

  it('toggles details when detail button is clicked', async () => {
    createComponent();
    await waitForPromises();

    expect(wrapper.text()).not.toContain('Last updated');
    await findDetailsButton().trigger('click');

    expect(wrapper.text()).toContain('Last updated');
  });

  it('renders TimeagoTooltip components with correct timestamps', async () => {
    createComponent();
    await waitForPromises();

    const timeagoComponents = wrapper.findAllComponents(TimeagoTooltip);
    expect(timeagoComponents.exists()).toBe(true);
    expect(timeagoComponents.at(0).props('time')).toBe(selectField.updatedAt);
  });

  it('refetches list after create-custom-field emits created', async () => {
    const customFieldsResponse = jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '123',
          customFields: {
            nodes: [],
            count: 0,
          },
        },
      },
    });

    createComponent({
      customFieldsResponse,
    });
    await waitForPromises();

    expect(customFieldsResponse).toHaveBeenCalledTimes(1);

    wrapper.findComponent(CreateCustomField).vm.$emit('created');

    expect(customFieldsResponse).toHaveBeenCalledTimes(2);
  });
});
