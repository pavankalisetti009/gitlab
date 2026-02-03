import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';

import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import aiCatalogAvailableFlowsForProjectQuery from 'ee/ai/duo_agents_platform/graphql/queries/ai_catalog_available_flows_for_project.query.graphql';
import { PAGE_SIZE } from 'ee/ai/catalog/constants';
import GroupItemConsumerDropdown from 'ee/ai/duo_agents_platform/components/catalog/group_item_consumer_dropdown.vue';
import SingleSelectDropdown from 'ee/ai/catalog/components/single_select_dropdown.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mockFlowItemConsumer, mockConfiguredFlowsResponse } from 'ee_jest/ai/catalog/mock_data';

Vue.use(VueApollo);

describe('GroupItemConsumerDropdown', () => {
  let wrapper;
  let mockApollo;

  const rootGroupId = 123;
  const projectId = 456;
  const defaultProps = {
    id: 'gl-form-field-item',
    dropdownTexts: {
      placeholder: 'Select an agent',
      itemSublabel: 'ID: %{id}',
    },
    itemTypes: ['AGENT'],
  };
  const mockConfiguredItemsQueryHandler = jest.fn().mockResolvedValue(mockConfiguredFlowsResponse);
  const mockAvailableFlowsQueryHandler = jest.fn().mockResolvedValue(mockConfiguredFlowsResponse);

  const createComponent = ({ props = {} } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogConfiguredItemsQuery, mockConfiguredItemsQueryHandler],
      [aiCatalogAvailableFlowsForProjectQuery, mockAvailableFlowsQueryHandler],
    ]);

    wrapper = shallowMount(GroupItemConsumerDropdown, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        rootGroupId,
        projectId,
      },
    });
  };

  const findSingleSelectDropdown = () => wrapper.findComponent(SingleSelectDropdown);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('when useRootGroupFlows is false (default)', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders SingleSelectDropdown with aiCatalogConfiguredItems query', () => {
      expect(findSingleSelectDropdown().props()).toMatchObject({
        id: 'gl-form-field-item',
        query: aiCatalogConfiguredItemsQuery,
        queryVariables: {
          groupId: convertToGraphQLId(TYPENAME_GROUP, rootGroupId),
          configurableForProjectId: convertToGraphQLId(TYPENAME_PROJECT, projectId),
          itemTypes: ['AGENT'],
          first: PAGE_SIZE,
          after: null,
          before: null,
          last: null,
        },
        dataKey: 'aiCatalogConfiguredItems',
        placeholderText: 'Select an agent',
        itemTextFn: expect.any(Function),
        itemLabelFn: expect.any(Function),
        itemSubLabelFn: expect.any(Function),
        isValid: true,
      });
    });

    it('passes value prop to SingleSelectDropdown', () => {
      createComponent({
        props: { value: 'gid://gitlab/Ai::Catalog::ItemConsumer/1' },
      });

      expect(findSingleSelectDropdown().props('value')).toBe(
        'gid://gitlab/Ai::Catalog::ItemConsumer/1',
      );
    });

    it('passes isValid prop to SingleSelectDropdown', () => {
      createComponent({ props: { isValid: false } });

      expect(findSingleSelectDropdown().props('isValid')).toBe(false);
    });
  });

  describe('when useRootGroupFlows is true', () => {
    beforeEach(() => {
      createComponent({
        props: {
          useRootGroupFlows: true,
          itemTypes: ['FLOW'],
          dropdownTexts: {
            placeholder: 'Select a flow',
            itemSublabel: 'ID: %{id}',
          },
        },
      });
    });

    it('renders SingleSelectDropdown with aiCatalogAvailableFlowsForProject query', () => {
      expect(findSingleSelectDropdown().props()).toMatchObject({
        query: aiCatalogAvailableFlowsForProjectQuery,
        queryVariables: {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, projectId),
          first: PAGE_SIZE,
          after: null,
          before: null,
          last: null,
        },
        dataKey: 'aiCatalogAvailableFlowsForProject',
        placeholderText: 'Select a flow',
      });
    });

    it('does not include groupId or itemTypes in query variables', () => {
      const { queryVariables } = findSingleSelectDropdown().props();

      expect(queryVariables.groupId).toBeUndefined();
      expect(queryVariables.itemTypes).toBeUndefined();
      expect(queryVariables.configurableForProjectId).toBeUndefined();
    });
  });

  describe('item formatting functions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('itemTextFn returns item name', () => {
      const { itemTextFn } = findSingleSelectDropdown().props();

      expect(itemTextFn(mockFlowItemConsumer)).toBe(mockFlowItemConsumer.item.name);
    });

    it('itemLabelFn returns item name', () => {
      const { itemLabelFn } = findSingleSelectDropdown().props();

      expect(itemLabelFn(mockFlowItemConsumer)).toBe(mockFlowItemConsumer.item.name);
    });

    it('itemSubLabelFn returns formatted ID', () => {
      const { itemSubLabelFn } = findSingleSelectDropdown().props();

      expect(itemSubLabelFn(mockFlowItemConsumer)).toBe('ID: 4');
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits input event when SingleSelectDropdown emits input', async () => {
      await waitForPromises();

      findSingleSelectDropdown().vm.$emit('input', mockFlowItemConsumer);

      expect(wrapper.emitted('input')).toEqual([[mockFlowItemConsumer]]);
    });

    it('emits error event when SingleSelectDropdown emits error', () => {
      findSingleSelectDropdown().vm.$emit('error');

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });
});
