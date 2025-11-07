import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';

import getProjects from '~/graphql_shared/queries/get_users_projects.query.graphql';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';
import SingleSelectDropdown from 'ee/ai/catalog/components/single_select_dropdown.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { ACCESS_LEVEL_MAINTAINER_STRING } from '~/access_level/constants';
import { mockProjects, mockProjectsResponse } from '../mock_data';

Vue.use(VueApollo);

describe('FormProjectDropdown', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    id: 'gl-form-field-project',
  };
  const mockProjectsQueryHandler = jest.fn().mockResolvedValue(mockProjectsResponse);

  const createComponent = ({ props = {} } = {}) => {
    mockApollo = createMockApollo([[getProjects, mockProjectsQueryHandler]]);

    wrapper = shallowMount(FormProjectDropdown, {
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
      id: 'gl-form-field-project',
      query: getProjects,
      queryVariables: {
        minAccessLevel: ACCESS_LEVEL_MAINTAINER_STRING,
        sort: 'similarity',
        searchNamespaces: true,
      },
      dataKey: 'projects',
      placeholderText: 'Select a project',
      itemTextFn: expect.any(Function),
      itemLabelFn: expect.any(Function),
      itemSubLabelFn: expect.any(Function),
      isValid: true,
      disabled: false,
    });
  });

  it('passes value prop to SingleSelectDropdown', () => {
    createComponent({ props: { value: 'gid://gitlab/Project/1' } });

    expect(findSingleSelectDropdown().props('value')).toBe('gid://gitlab/Project/1');
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

      findSingleSelectDropdown().vm.$emit('input', mockProjects[0]);

      expect(wrapper.emitted('input')).toEqual([[mockProjects[0].id]]);
    });

    it('emits error event when SingleSelectDropdown emits error', () => {
      findSingleSelectDropdown().vm.$emit('error');

      expect(wrapper.emitted('error')).toEqual([['Failed to load projects']]);
    });
  });
});
