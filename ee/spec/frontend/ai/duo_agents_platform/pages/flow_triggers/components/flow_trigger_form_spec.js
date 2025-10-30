import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlForm, GlFormTextarea, GlFormRadioGroup, GlFormInput } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import UserSelect from '~/vue_shared/components/user_select/user_select.vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import FlowTriggerForm from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_form.vue';
import getCatalogConsumerItemsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_catalog_consumer_items.query.graphql';
import AiLegalDisclaimer from 'ee/ai/duo_agents_platform/components/common/ai_legal_disclaimer.vue';
import { eventTypeOptions, mockCatalogFlowsResponse } from '../mocks';

Vue.use(VueApollo);

describe('FlowTriggerForm', () => {
  let wrapper;

  const catalogFlowsHandler = jest.fn();

  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findForm = () => wrapper.findComponent(GlForm);
  const findDescription = () => wrapper.findComponent(GlFormTextarea);
  const findEventTypes = () => wrapper.find('[data-testid="trigger-event-type-listbox"]');
  const findFlowSelect = () => wrapper.find('[data-testid="trigger-agent-listbox"]');
  const findUserSelect = () => wrapper.findComponent(UserSelect);
  const findConfigModeRadio = () => wrapper.findComponent(GlFormRadioGroup);
  const findConfigPathInput = () => wrapper.findComponent(GlFormInput);
  const findSubmitButton = () => wrapper.findByTestId('trigger-submit-button');
  const findAiLegalDisclaimer = () => wrapper.findComponent(AiLegalDisclaimer);

  const defaultProps = {
    mode: 'create',
    isLoading: false,
    errorMessages: [],
    eventTypeOptions,
    projectPath: 'myProject',
    projectId: '123',
  };

  const createWrapper = async (props = {}, provide = {}) => {
    const handlers = [[getCatalogConsumerItemsQuery, catalogFlowsHandler]];

    wrapper = shallowMountExtended(FlowTriggerForm, {
      apolloProvider: createMockApollo(handlers),
      propsData: { ...defaultProps, ...props },
      provide: {
        glFeatures: {
          aiCatalogFlows: true,
          aiCatalogThirdPartyFlows: true,
        },
        ...provide,
      },
      stubs: {
        ErrorsAlert,
        UserSelect: true,
        AiLegalDisclaimer,
      },
    });

    await waitForPromises();
    return wrapper;
  };

  beforeEach(() => {
    catalogFlowsHandler.mockResolvedValue(mockCatalogFlowsResponse);
  });

  describe('Default rendering', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders errors alert component with no errors', () => {
      expect(findErrorsAlert().exists()).toBe(true);
      expect(findErrorsAlert().props('errors')).toEqual([]);
    });

    it('renders form components', () => {
      expect(findForm().exists()).toBe(true);
      expect(findDescription().exists()).toBe(true);
      expect(findEventTypes().exists()).toBe(true);
      expect(findUserSelect().exists()).toBe(true);
      expect(findConfigModeRadio().exists()).toBe(true);
      expect(findSubmitButton().exists()).toBe(true);
      expect(findAiLegalDisclaimer().exists()).toBe(true);
    });
  });

  describe('Configuration Mode', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('defaults to catalog mode', () => {
      expect(findFlowSelect().exists()).toBe(true);
      expect(findConfigPathInput().exists()).toBe(false);
      expect(findFlowSelect().props('headerText')).toBe('Select a flow from the AI Catalog');
    });

    describe('when switching to manual mode', () => {
      it('shows config path input and hides flow select', async () => {
        await findConfigModeRadio().vm.$emit('input', 'manual');

        expect(findConfigPathInput().exists()).toBe(true);
        expect(findFlowSelect().exists()).toBe(false);
      });
    });

    describe('configMode initialization', () => {
      describe('when aiCatalogItemConsumer has an id', () => {
        beforeEach(async () => {
          await createWrapper({
            initialValues: {
              description: '',
              eventTypes: [],
              configPath: 'some/path',
              user: null,
              aiCatalogItemConsumer: { id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1' },
            },
          });
        });

        it('defaults to catalog mode', () => {
          expect(findConfigModeRadio().attributes('checked')).toBe('catalog');
          expect(findFlowSelect().exists()).toBe(true);
          expect(findConfigPathInput().exists()).toBe(false);
        });
      });

      describe('when aiCatalogItemConsumer has no id', () => {
        describe('and configPath is empty', () => {
          beforeEach(async () => {
            await createWrapper({
              initialValues: {
                description: '',
                eventTypes: [],
                configPath: '',
                user: null,
                aiCatalogItemConsumer: {},
              },
            });
          });

          it('defaults to catalog mode', () => {
            expect(findConfigModeRadio().attributes('checked')).toBe('catalog');
            expect(findFlowSelect().exists()).toBe(true);
            expect(findConfigPathInput().exists()).toBe(false);
          });
        });

        describe('and configPath exists', () => {
          beforeEach(async () => {
            await createWrapper({
              initialValues: {
                description: '',
                eventTypes: [],
                configPath: 'existing/config/path.yml',
                user: null,
                aiCatalogItemConsumer: {},
              },
            });
          });

          it('defaults to manual mode', () => {
            expect(findConfigModeRadio().attributes('checked')).toBe('manual');
            expect(findConfigPathInput().exists()).toBe(true);
            expect(findFlowSelect().exists()).toBe(false);
          });
        });
      });

      describe('when both AI Catalog flow feature flags are false', () => {
        beforeEach(async () => {
          await createWrapper(
            {},
            { glFeatures: { aiCatalogFlows: false, aiCatalogThirdPartyFlows: false } },
          );
        });

        it('defaults to manual mode', () => {
          expect(findConfigModeRadio().exists()).toBe(false);
          expect(findFlowSelect().exists()).toBe(false);
          expect(findConfigPathInput().exists()).toBe(true);
        });
      });
    });
  });

  describe('Flow Selection', () => {
    describe('when there is a default value selected', () => {
      beforeEach(async () => {
        await createWrapper({
          initialValues: {
            description: 'Initial description',
            eventTypes: [eventTypeOptions[0].value],
            configPath: 'initial/path',
            user: { id: 'gid://gitlab/User/1', name: 'Initial User' },
            aiCatalogItemConsumer: {
              id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
              name: 'Test Flow',
            },
          },
        });
      });

      it('shows this value as selected', () => {
        expect(findFlowSelect().props().items).toHaveLength(2);
        expect(findFlowSelect().props().selected).toBe('gid://gitlab/Ai::Catalog::ItemConsumer/1');
      });
    });

    describe('when there are no default value selected', () => {
      beforeEach(async () => {
        await createWrapper();
      });

      it('shows default text', () => {
        expect(findFlowSelect().props('toggleText')).toBe('Select a flow from the AI Catalog');
        expect(findFlowSelect().props().items).toHaveLength(2);
        expect(findFlowSelect().props().selected).toEqual([]);
      });

      describe('and user selects a flow', () => {
        const selectedValue = 'gid://gitlab/Ai::Catalog::ItemConsumer/1';

        beforeEach(async () => {
          await findFlowSelect().vm.$emit('select', selectedValue);
        });

        it('updates selected flow', () => {
          expect(findFlowSelect().props().items).toHaveLength(2);
          expect(findFlowSelect().props().selected).toBe(selectedValue);
        });

        it('shows correct toggle', async () => {
          expect(findFlowSelect().props('items')).toHaveLength(2);

          await findFlowSelect().vm.$emit('select', 'gid://gitlab/Ai::Catalog::ItemConsumer/1');

          expect(findFlowSelect().props('toggleText')).toBe('Test Flow');
        });
      });
    });
  });

  describe('Event Type Selection', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('shows correct toggle text when event types are selected', async () => {
      const selectedEventTypes = [eventTypeOptions[0].value, eventTypeOptions[1].value];
      await findEventTypes().vm.$emit('select', selectedEventTypes);

      const expectedText = `${eventTypeOptions[0].text}, ${eventTypeOptions[1].text}`;
      expect(findEventTypes().props('toggleText')).toBe(expectedText);
    });

    it('shows default text when no event types are selected', () => {
      expect(findEventTypes().props('toggleText')).toBe('Select one or multiple event types');
    });
  });

  describe('User Selection', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('shows correct user name when user is selected', async () => {
      const mockUser = { id: 1, name: 'Test User' };
      await findUserSelect().vm.$emit('input', [mockUser]);

      expect(findUserSelect().props('text')).toBe('Test User');
    });

    it('shows default text when no user is selected', () => {
      expect(findUserSelect().props('text')).toBe('Select user');
    });

    it('handles user select error', async () => {
      await findUserSelect().vm.$emit('error');

      expect(findErrorsAlert().props('errors')).toEqual([
        'An error occurred while fetching users.',
      ]);
    });

    it('processes users data correctly', () => {
      const user1 = { id: 1, name: 'User 1' };
      const user2 = { id: 2, name: 'User 2' };
      const data = { project: { projectMembers: { nodes: [{ user: user1 }, { user: user2 }] } } };

      const processor = findUserSelect().props('customSearchUsersProcessor');
      const result = processor(data);

      expect(result).toEqual([user1, user2]);
    });

    it('handles empty users data', () => {
      const data = { project: { projectMembers: { nodes: [] } } };
      const processor = findUserSelect().props('customSearchUsersProcessor');
      const result = processor(data);

      expect(result).toEqual([]);
    });
  });

  describe('Form Submit', () => {
    describe('when in catalog mode', () => {
      const description = 'My description';
      const eventTypes = [eventTypeOptions[0].value];
      const selectedFlow = 'gid://gitlab/Ai::Catalog::ItemConsumer/1';
      const mockUser = { id: 'gid://gitlab/User/1', name: 'Test User' };

      beforeEach(async () => {
        await createWrapper();
      });

      it('submits the form with selected flow', async () => {
        expect(findFlowSelect().props('items')).toHaveLength(2);

        await findDescription().vm.$emit('input', description);
        await findEventTypes().vm.$emit('select', eventTypes);
        await findUserSelect().vm.$emit('input', [mockUser]);
        await findFlowSelect().vm.$emit('select', selectedFlow);

        await findForm().vm.$emit('submit', { preventDefault: () => {} });

        expect(wrapper.emitted('submit')).toEqual([
          [
            {
              configPath: '',
              description,
              eventTypes,
              userId: 'gid://gitlab/User/1',
              aiCatalogItemConsumerId: selectedFlow,
            },
          ],
        ]);
      });
    });

    describe('when in manual mode', () => {
      const description = 'My description';
      const eventTypes = [eventTypeOptions[0].value];
      const configPath = 'path/to/config.yml';
      const mockUser = { id: 'gid://gitlab/User/1', name: 'Test User' };

      beforeEach(async () => {
        await createWrapper();
      });

      it('submits the form with config path', async () => {
        await findConfigModeRadio().vm.$emit('input', 'manual');

        await findDescription().vm.$emit('input', description);
        await findEventTypes().vm.$emit('select', eventTypes);
        await findUserSelect().vm.$emit('input', [mockUser]);
        await findConfigPathInput().vm.$emit('input', configPath);

        await findForm().vm.$emit('submit', { preventDefault: () => {} });

        expect(wrapper.emitted('submit')).toEqual([
          [
            {
              configPath,
              description,
              eventTypes,
              userId: 'gid://gitlab/User/1',
              aiCatalogItemConsumerId: null,
            },
          ],
        ]);
      });
    });

    describe('when no user is selected', () => {
      beforeEach(async () => {
        await createWrapper();
      });
      it('submits with null userId', async () => {
        await findDescription().vm.$emit('input', 'Test description');
        await findEventTypes().vm.$emit('select', [eventTypeOptions[0].value]);
        // Don't select any user

        await findForm().vm.$emit('submit', { preventDefault: () => {} });

        expect(wrapper.emitted('submit')[0][0].userId).toBe(null);
      });
    });
  });

  describe('Initial Values', () => {
    beforeEach(async () => {
      const initialValues = {
        description: 'Initial description',
        eventTypes: [eventTypeOptions[0].value],
        configPath: 'initial/path',
        user: { id: 'gid://gitlab/User/1', name: 'Initial User' },
        aiCatalogItemConsumer: {},
      };

      await createWrapper({ initialValues });
    });

    it('sets initial values correctly', () => {
      expect(findDescription().props('value')).toBe('Initial description');
      expect(findEventTypes().props('selected')).toEqual([eventTypeOptions[0].value]);

      expect(findUserSelect().props('value')).toEqual([
        { id: 'gid://gitlab/User/1', name: 'Initial User' },
      ]);
    });
  });

  describe('Error handling', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    describe('when errors are present', () => {
      beforeEach(async () => {
        await findUserSelect().vm.$emit('error');
      });

      it('shows errors in ErrorsAlert component', () => {
        expect(findErrorsAlert().props('errors')).toEqual([
          'An error occurred while fetching users.',
        ]);
      });

      describe('and errors are dismissed', () => {
        beforeEach(async () => {
          await findErrorsAlert().vm.$emit('dismiss');
        });

        it('clears the errors', () => {
          expect(findErrorsAlert().props('errors')).toEqual([]);
        });
      });
    });
  });

  describe('Apollo queries', () => {
    describe('catalog flows query', () => {
      beforeEach(async () => {
        await createWrapper();
      });

      it('fetches catalog flows on mount', () => {
        expect(catalogFlowsHandler).toHaveBeenCalledWith({
          projectId: 'gid://gitlab/Project/123',
          itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
        });
      });

      it('handles catalog flows query error', async () => {
        catalogFlowsHandler.mockRejectedValue(new Error('Network error'));
        await createWrapper();

        expect(findErrorsAlert().props('errors')).toEqual([
          'An error occurred while fetching flows configured for this project.',
        ]);
      });
    });
  });
});
