import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlIcon, GlModal } from '@gitlab/ui';
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

  const aiCatalogAgentsQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);
  const aiCatalogEmptyAgentsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockCatalogEmptyItemsResponse);

  const createComponent = ({ catalogItemsQueryHandler = aiCatalogAgentsQueryHandler } = {}) => {
    mockApollo = createMockApollo([[aiCatalogAgentsQuery, catalogItemsQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogStepsEditor, {
      apolloProvider: mockApollo,
    });
  };

  const findLabel = () => wrapper.findByTestId('flow-edit-steps');
  const findNodeField = () => wrapper.findComponent(AiCatalogNodeField);
  const findModal = () => wrapper.findComponent(GlModal);
  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findIcon = () => wrapper.findComponent(GlIcon);

  beforeEach(() => {
    createComponent();
  });

  describe('rendering', () => {
    it('renders the label with correct text and icon', () => {
      const label = findLabel();
      expect(label.exists()).toBe(true);
      expect(label.text()).toBe('Flow nodes (Coming soon)');

      const icon = findIcon();
      expect(icon.exists()).toBe(true);
      expect(icon.props('name')).toBe('diagram');
    });

    it('renders the AiCatalogNodeField component', () => {
      expect(findNodeField().exists()).toBe(true);
    });

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
      findListbox().vm.$emit('select', selectedAgent.value);
      await nextTick();

      expect(findNodeField().props('selected')).toMatchObject(selectedAgent);
      expect(findListbox().props('toggleText')).toEqual(selectedAgent.text);
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
    it('opens modal when AiCatalogNodeField emits primary event', async () => {
      await waitForPromises();
      findNodeField().vm.$emit('primary');
      await nextTick();

      expect(findModal().props('visible')).toBe(true);
    });

    it('clears selected agent on cancel and closes modal', async () => {
      await waitForPromises();
      findListbox().vm.$emit('select', 'gid://gitlab/Ai::Catalog::Item/1');
      await nextTick();

      expect(findNodeField().props('selected')).toMatchObject(selectedAgent);

      findModal().vm.$emit('cancel');
      await nextTick();

      expect(findNodeField().props('selected')).toBeNull();
      expect(findModal().props('visible')).toBe(false);
    });
  });
});
