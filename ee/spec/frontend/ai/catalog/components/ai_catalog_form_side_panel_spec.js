import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogFormSidePanel from 'ee/ai/catalog/components/ai_catalog_form_side_panel.vue';
import aiCatalogAgentsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agents.query.graphql';
import {
  mockCatalogItemsResponse,
  mockCatalogEmptyItemsResponse,
  mockAgentVersions,
} from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogFormSidePanel', () => {
  let wrapper;
  let mockApollo;

  const versionName = '1.0.0';
  const versionOptions = [{ text: '1.0.0', value: 'gid://gitlab/Ai::Catalog::ItemVersion/20' }];

  const agents = [
    {
      value: 'gid://gitlab/Ai::Catalog::Item/1',
      text: 'Test AI Agent 1',
      versions: mockAgentVersions,
      public: true,
    },
    {
      value: 'gid://gitlab/Ai::Catalog::Item/2',
      text: 'Test AI Agent 2',
      versions: mockAgentVersions,
      public: true,
    },
    {
      value: 'gid://gitlab/Ai::Catalog::Item/3',
      text: 'Test AI Agent 3',
      versions: mockAgentVersions,
      public: false,
    },
  ];

  const selectedAgent = agents[0];

  const selectedSteps = [
    {
      id: 'gid://gitlab/Ai::Catalog::Item/1',
      name: 'Test AI Agent 1',
      versionName,
      versions: mockAgentVersions,
    },
    {
      id: 'gid://gitlab/Ai::Catalog::Item/3',
      name: 'Test AI Agent 3',
      versionName,
      versions: mockAgentVersions,
    },
  ];

  const aiCatalogAgentsQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);
  const aiCatalogEmptyAgentsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockCatalogEmptyItemsResponse);

  const createComponent = ({
    catalogItemsQueryHandler = aiCatalogAgentsQueryHandler,
    steps = [],
    activeStepIndex = 0,
    aiCatalogEnforceReadonlyVersions = true,
    isFlowPublic = false,
  } = {}) => {
    mockApollo = createMockApollo([[aiCatalogAgentsQuery, catalogItemsQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogFormSidePanel, {
      apolloProvider: mockApollo,
      propsData: {
        steps,
        activeStepIndex,
        isFlowPublic,
      },
      provide: {
        glFeatures: {
          aiCatalogEnforceReadonlyVersions,
        },
      },
    });
  };
  const findSaveButton = () => wrapper.findComponent(GlButton);
  const findAgentListbox = () => wrapper.findByTestId('agent-select-listbox');
  const findAgentListboxLabel = () => wrapper.findByTestId('agent-select-listbox-label');
  const findVersionListbox = () => wrapper.findByTestId('version-select-listbox');
  const findCancelButton = () => wrapper.findByTestId('agent-select-cancel-button');
  const findDeleteNodeButton = () => wrapper.findByTestId('agent-node-delete-button');

  const selectAgent = async () => {
    findAgentListbox().vm.$emit('select', selectedAgent.value);
    await nextTick();
    expect(findAgentListbox().props('toggleText')).toEqual(selectedAgent.text);
  };

  beforeEach(() => {
    createComponent();
  });

  describe('listbox', () => {
    it('renders the listbox with loading state', () => {
      expect(findAgentListbox().exists()).toBe(true);
      expect(findAgentListbox().props('loading')).toBe(true);
    });

    it('does not render help text when flow is private', () => {
      expect(findAgentListboxLabel().text()).not.toContain(
        'Only public agents can be used in public flows.',
      );
    });

    it('version listbox is disabled when no agent is selected', () => {
      expect(findVersionListbox().exists()).toBe(true);
      expect(findVersionListbox().props('disabled')).toBe(true);
    });

    it('version listbox does not exist when aiCatalogEnforceReadonlyVersions FF is off', async () => {
      createComponent({ aiCatalogEnforceReadonlyVersions: false });
      await waitForPromises();

      expect(findVersionListbox().exists()).toBe(false);
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

      expect(findAgentListbox().props('items')).toEqual(agents);
    });

    it('sets loading in listbox to false after query completes', async () => {
      await waitForPromises();
      expect(findAgentListbox().props('loading')).toBe(false);
    });

    it('handles empty query response', async () => {
      createComponent({ catalogItemsQueryHandler: aiCatalogEmptyAgentsQueryHandler });
      await waitForPromises();

      expect(findAgentListbox().props('items')).toEqual([]);
    });
  });

  describe('when the flow being edited is public', () => {
    beforeEach(async () => {
      createComponent({ isFlowPublic: true });
      await waitForPromises();
    });

    it('does not render private agents as options', () => {
      expect(findAgentListbox().props('items')).toEqual([agents[0], agents[1]]);
    });

    it('renders help text', () => {
      expect(findAgentListboxLabel().text()).toContain(
        'Only public agents can be used in public flows.',
      );
    });
  });

  describe('agent selection', () => {
    it('emits setSteps event when saving', async () => {
      await waitForPromises();
      await selectAgent();
      findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('setSteps')).toEqual([[[selectedSteps[0]]]]);
    });

    it('passes correct props to GlCollapsibleListbox', async () => {
      await waitForPromises();

      const listbox = findAgentListbox();
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
      const listbox = findAgentListbox();
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

  describe('version selection', () => {
    it('version listbox is enabled when agent is selected', async () => {
      await waitForPromises();
      await selectAgent();

      expect(findVersionListbox().props('disabled')).toBe(false);
      expect(findVersionListbox().props('items')).toEqual(versionOptions);
    });

    it('emits setSteps event when saving', async () => {
      await waitForPromises();
      await selectAgent();

      findVersionListbox().vm.$emit('select', versionOptions[0].value);
      await nextTick();
      expect(findVersionListbox().props('toggleText')).toEqual(versionOptions[0].text);

      findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('setSteps')).toEqual([[[selectedSteps[0]]]]);
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
