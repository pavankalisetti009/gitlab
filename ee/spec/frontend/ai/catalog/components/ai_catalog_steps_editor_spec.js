import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlCollapsibleListbox, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogStepsEditor from 'ee/ai/catalog/components/ai_catalog_steps_editor.vue';
import AiCatalogNodeField from 'ee/ai/catalog/components/ai_catalog_node_field.vue';
import aiCatalogAgentsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agents.query.graphql';
import { mockCatalogItemsResponse, mockCatalogEmptyItemsResponse } from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogStepsEditor', () => {
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
  } = {}) => {
    mockApollo = createMockApollo([[aiCatalogAgentsQuery, catalogItemsQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogStepsEditor, {
      apolloProvider: mockApollo,
      propsData: {
        steps,
      },
    });
  };

  const findNewNodeButton = () => wrapper.findComponent(GlButton);
  const findNodeFields = () => wrapper.findAllComponents(AiCatalogNodeField);
  const findFirstNodeField = () => findNodeFields().at(0);
  const findModal = () => wrapper.findComponent(GlModal);
  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  const selectAgent = async () => {
    findNewNodeButton().vm.$emit('click');
    await nextTick();
    findListbox().vm.$emit('select', selectedAgent.value);
    await nextTick();
    expect(findListbox().props('toggleText')).toEqual(selectedAgent.text);
    findModal().vm.$emit('primary');
  };

  beforeEach(() => {
    createComponent();
  });

  describe('empty state', () => {
    it('renders new node button', () => {
      expect(findNewNodeButton().exists()).toBe(true);
      expect(findNewNodeButton().text()).toEqual('Flow node');
      expect(findNewNodeButton().props('icon')).toEqual('plus');
    });

    it('does not render the AiCatalogNodeField component', () => {
      expect(findNodeFields()).toHaveLength(0);
    });
  });

  describe('with existing steps', () => {
    beforeEach(() => {
      createComponent({ steps: selectedSteps });
    });

    it('renders as many AiCatalogNodeField components as there are steps', () => {
      expect(findNodeFields()).toHaveLength(2);
      expect(findFirstNodeField().props('selected')).toMatchObject(agents[0]);
      expect(findNodeFields().at(1).props('selected')).toMatchObject(agents[2]);
    });
  });

  describe('modal', () => {
    it('renders the modal with correct props, not visible by default', () => {
      const modal = findModal();
      expect(modal.exists()).toBe(true);
      expect(modal.props('title')).toBe('Draft node');
      expect(modal.props('visible')).toBe(false);
    });

    it('renders the listbox inside the modal, with loading state', () => {
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

  describe('component interactions', () => {
    it('selects agent', async () => {
      await waitForPromises();
      await selectAgent();

      expect(wrapper.emitted('setSteps')).toEqual([[[selectedSteps[0]]]]);
    });

    it('updates existing step agent', async () => {
      createComponent({ steps: [{ id: agents[0].value, name: agents[0].text }] });
      await waitForPromises();

      findFirstNodeField().vm.$emit('primary');
      await nextTick();
      findListbox().vm.$emit('select', agents[1].value);
      await nextTick();
      expect(findListbox().props('toggleText')).toEqual(agents[1].text);
      findModal().vm.$emit('primary');
      await nextTick();

      expect(wrapper.emitted('setSteps')).toEqual([
        [[{ id: agents[1].value, name: agents[1].text }]],
      ]);
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

  describe('modal behavior', () => {
    it('opens modal on click new node button', async () => {
      await waitForPromises();
      findNewNodeButton().vm.$emit('click');
      await nextTick();

      expect(findModal().props('visible')).toBe(true);
    });

    it('opens modal when AiCatalogNodeField emits primary event', async () => {
      createComponent({ steps: selectedSteps });
      await waitForPromises();
      findFirstNodeField().vm.$emit('primary');
      await nextTick();

      expect(findModal().props('visible')).toBe(true);
    });

    it('clears selected agent on cancel and closes modal', async () => {
      await waitForPromises();
      findListbox().vm.$emit('select', 'gid://gitlab/Ai::Catalog::Item/1');
      await nextTick();

      expect(findListbox().props('toggleText')).toEqual(selectedAgent.text);

      findModal().vm.$emit('cancel');
      await nextTick();

      expect(findListbox().props('toggleText')).toEqual('Select agent');
      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('v-model', () => {
    it('should set steps and update the v-model bound data', async () => {
      await waitForPromises();
      expect(findNodeFields()).toHaveLength(0);

      await selectAgent();

      expect(wrapper.emitted('setSteps')).toEqual([[[selectedSteps[0]]]]);
    });
  });
});
