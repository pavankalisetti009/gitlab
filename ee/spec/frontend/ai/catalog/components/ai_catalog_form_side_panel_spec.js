import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogFormSidePanel from 'ee/ai/catalog/components/ai_catalog_form_side_panel.vue';
import aiCatalogAgentsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agents.query.graphql';
import { mockCatalogItemsResponse, mockCatalogEmptyItemsResponse } from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogFormSidePanel', () => {
  let wrapper;
  let mockApollo;

  const agents = [
    { value: 'gid://gitlab/Ai::Catalog::Item/1', text: 'Test AI Agent 1' },
    { value: 'gid://gitlab/Ai::Catalog::Item/2', text: 'Test AI Agent 2' },
    { value: 'gid://gitlab/Ai::Catalog::Item/3', text: 'Test AI Agent 3' },
  ];

  const selectedAgent = agents[0];

  const selectedSteps = [
    { id: 'gid://gitlab/Ai::Catalog::Item/1', name: 'Test AI Agent 1' },
    { id: 'gid://gitlab/Ai::Catalog::Item/3', name: 'Test AI Agent 3' },
  ];

  const aiCatalogAgentsQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);
  const aiCatalogEmptyAgentsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockCatalogEmptyItemsResponse);

  const createComponent = ({
    catalogItemsQueryHandler = aiCatalogAgentsQueryHandler,
    steps = [],
    activeStepIndex = 0,
  } = {}) => {
    mockApollo = createMockApollo([[aiCatalogAgentsQuery, catalogItemsQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogFormSidePanel, {
      apolloProvider: mockApollo,
      propsData: {
        steps,
        activeStepIndex,
      },
    });
  };
  const findSaveButton = () => wrapper.findComponent(GlButton);
  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCancelButton = () => wrapper.findByTestId('agent-select-cancel-button');
  const findDeleteNodeButton = () => wrapper.findByTestId('agent-node-delete-button');

  const selectAgent = async () => {
    findListbox().vm.$emit('select', selectedAgent.value);
    await nextTick();
    expect(findListbox().props('toggleText')).toEqual(selectedAgent.text);
    findSaveButton().vm.$emit('click');
  };

  beforeEach(() => {
    createComponent();
  });

  describe('listbox', () => {
    it('renders the listbox with loading state', () => {
      expect(findListbox().exists()).toBe(true);
      expect(findListbox().props('loading')).toBe(true);
    });
  });

  describe('fetches agents', () => {
    it('calls the aiCatalogAgents query with correct variables', () => {
      expect(aiCatalogAgentsQueryHandler).toHaveBeenCalledWith({
        search: '',
      });
    });

    it('passes transformed aiCatalogAgents as listbox items', async () => {
      await waitForPromises();

      expect(findListbox().props('items')).toEqual(agents);
    });

    it('sets loading in listbox to false after query completes', async () => {
      await waitForPromises();
      expect(findListbox().props('loading')).toBe(false);
    });

    it('handles empty query response', async () => {
      createComponent({ catalogItemsQueryHandler: aiCatalogEmptyAgentsQueryHandler });
      await waitForPromises();

      expect(findListbox().props('items')).toEqual([]);
    });
  });

  describe('agent selection', () => {
    it('emits setSteps event', async () => {
      await waitForPromises();
      await selectAgent();

      expect(wrapper.emitted('setSteps')).toEqual([[[selectedSteps[0]]]]);
    });

    it('passes correct props to GlCollapsibleListbox', async () => {
      await waitForPromises();

      const listbox = findListbox();
      expect(listbox.props()).toMatchObject({
        block: true,
        searchable: true,
        items: agents,
        toggleText: 'Select agent',
        loading: false,
        searching: false,
      });
    });

    it('handles listbox search event', async () => {
      const listbox = findListbox();
      listbox.vm.$emit('search', 'new search');
      await nextTick();

      expect(listbox.props('searching')).toBe(true);
      expect(aiCatalogAgentsQueryHandler).toHaveBeenCalledWith({
        search: 'new search',
      });

      await waitForPromises();
      expect(listbox.props('searching')).toBe(false);
    });
  });

  describe('on cancel', () => {
    it('emits close event and does not emit setSteps', async () => {
      await waitForPromises();

      findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('close')).toHaveLength(1);
      expect(wrapper.emitted('setSteps')).toBeUndefined();
    });
  });

  describe('on delete', () => {
    it('emits setSteps and close event', async () => {
      createComponent({ steps: selectedSteps });
      await waitForPromises();

      findDeleteNodeButton().vm.$emit('click');

      expect(wrapper.emitted('setSteps')).toEqual([[[selectedSteps[1]]]]);
      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });
});
