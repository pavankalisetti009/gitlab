import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';

import getGroups from '~/graphql_shared/queries/get_users_groups.query.graphql';
import FormGroupDropdown from 'ee/ai/catalog/components/form_group_dropdown.vue';
import SingleSelectDropdown from 'ee/ai/catalog/components/single_select_dropdown.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

// Mock data
const mockGroups = [
  {
    id: 'gid://gitlab/Group/1',
    name: 'Group 1',
    fullName: 'Full Group 1',
    fullPath: 'group-1',
    avatarUrl: 'https://example.com/avatar1.png',
  },
  {
    id: 'gid://gitlab/Group/2',
    name: 'Group 2',
    fullName: 'Full Group 2',
    fullPath: 'group-2',
    avatarUrl: 'https://example.com/avatar2.png',
  },
];

const mockGroupsResponse = {
  data: {
    groups: {
      nodes: mockGroups,
      pageInfo: {
        hasNextPage: true,
        endCursor: 'cursor123',
      },
    },
  },
};

describe('FormGroupDropdown', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    id: 'gl-form-field-group',
  };
  const mockGroupsQueryHandler = jest.fn().mockResolvedValue(mockGroupsResponse);

  const createComponent = ({ props = {} } = {}) => {
    mockApollo = createMockApollo([[getGroups, mockGroupsQueryHandler]]);

    wrapper = shallowMount(FormGroupDropdown, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findSingleSelectDropdown = () => wrapper.findComponent(SingleSelectDropdown);

  beforeEach(() => {
    createComponent();
  });

  it('renders SingleSelectDropdown with correct props', () => {
    expect(findSingleSelectDropdown().props()).toMatchObject({
      id: 'gl-form-field-group',
      query: getGroups,
      queryVariables: {
        topLevelOnly: true,
        ownedOnly: true,
        sort: 'similarity',
      },
      dataKey: 'groups',
      placeholderText: 'Select a group',
      itemTextFn: expect.any(Function),
      itemLabelFn: expect.any(Function),
      itemSubLabelFn: expect.any(Function),
      isValid: true,
      disabled: false,
    });
  });

  it('passes value prop to SingleSelectDropdown', () => {
    createComponent({ props: { value: 'gid://gitlab/Group/1' } });

    expect(findSingleSelectDropdown().props('value')).toBe('gid://gitlab/Group/1');
  });

  it('passes isValid prop to SingleSelectDropdown', () => {
    createComponent({ props: { isValid: false } });

    expect(findSingleSelectDropdown().props('isValid')).toBe(false);
  });

  it('passes disabled prop to SingleSelectDropdown', () => {
    createComponent({ props: { disabled: true } });

    expect(findSingleSelectDropdown().props('disabled')).toBe(true);
  });

  describe('event handling', () => {
    it('emits input event when SingleSelectDropdown emits input', async () => {
      await waitForPromises();

      findSingleSelectDropdown().vm.$emit('input', mockGroups[0]);

      expect(wrapper.emitted('input')).toEqual([[mockGroups[0].id]]);
    });

    it('emits error event when SingleSelectDropdown emits error', () => {
      findSingleSelectDropdown().vm.$emit('error');

      expect(wrapper.emitted('error')).toEqual([['Failed to load groups.']]);
    });
  });
});
