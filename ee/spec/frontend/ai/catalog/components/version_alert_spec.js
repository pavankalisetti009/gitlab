import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import VersionAlert from 'ee/ai/catalog/components/version_alert.vue';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import updateAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_AGENT,
  VERSION_PINNED,
  VERSION_PINNED_GROUP,
  VERSION_LATEST,
} from 'ee/ai/catalog/constants';
import {
  mockUpdateAiCatalogItemConsumerSuccess,
  mockUpdateAiCatalogItemConsumerError,
  mockVersionProp,
  mockAiCatalogAgentResponse,
  mockAiCatalogFlowResponse,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('VersionAlert', () => {
  let wrapper;
  let mockApollo;

  const UPDATE_MESSAGES = {
    project: {
      flow: 'Only this flow in this project will be updated. Other projects using this flow will not be affected.',
      agent:
        'Only this agent in this project will be updated. Other projects using this agent will not be affected.',
    },
    group: {
      flow: "Updating a flow in this group does not update the flows enabled in this group's projects.",
      agent:
        "Updating an agent in this group does not update the agents enabled in this group's projects.",
    },
  };

  const SUCCESS_TOAST_MESSAGES = {
    flow: 'Flow is now at version 2.0.0.',
    agent: 'Agent is now at version 2.0.0.',
  };

  const mockLatestVersion = {
    humanVersionName: 'v2.0.0',
    versionName: '2.0.0',
  };

  const mockConfiguration = {
    id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
    groupId: null,
  };

  const mockToast = {
    show: jest.fn(),
  };

  const mockAgentQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);
  const mockFlowQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowResponse);
  const mockUpdateAiCatalogItemConsumerHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogItemConsumerSuccess);

  const createComponent = ({ props = {}, provide = {}, mocks = {} } = {}) => {
    const defaultProps = {
      itemType: AI_CATALOG_TYPE_FLOW,
      configuration: mockConfiguration,
      latestVersion: mockLatestVersion,
      version: null,
      ...props,
    };

    const defaultProvide = {
      projectId: '1',
      groupId: null,
      ...provide,
    };

    const defaultMocks = {
      $toast: mockToast,
      ...mocks,
    };

    mockApollo = createMockApollo([
      [aiCatalogAgentQuery, mockAgentQueryHandler],
      [aiCatalogFlowQuery, mockFlowQueryHandler],
      [updateAiCatalogItemConsumer, mockUpdateAiCatalogItemConsumerHandler],
    ]);

    mockApollo.clients.defaultClient
      .watchQuery({
        query: aiCatalogAgentQuery,
      })
      .subscribe();

    mockApollo.clients.defaultClient
      .watchQuery({
        query: aiCatalogFlowQuery,
      })
      .subscribe();

    wrapper = shallowMountExtended(VersionAlert, {
      apolloProvider: mockApollo,
      propsData: defaultProps,
      provide: defaultProvide,
      mocks: defaultMocks,
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findPrimaryButtonText = () => findAlert().props('primaryButtonText');
  const findSecondaryButtonText = () => findAlert().props('secondaryButtonText');

  describe.each([
    { namespace: 'project', projectId: '1', groupId: null, versionKey: VERSION_PINNED },
    { namespace: 'group', projectId: null, groupId: '1', versionKey: VERSION_PINNED_GROUP },
  ])('when in the $namespace namespace', ({ namespace, projectId, groupId, versionKey }) => {
    describe.each([
      { itemType: AI_CATALOG_TYPE_FLOW, itemName: 'flow' },
      { itemType: AI_CATALOG_TYPE_AGENT, itemName: 'agent' },
    ])('with $itemName item type', ({ itemType, itemName }) => {
      describe('when there is an update available', () => {
        const mockVersionWithUpdate = {
          ...mockVersionProp,
          isUpdateAvailable: true,
          activeVersionKey: versionKey, // initializes to the baseVersionKey
          baseVersionKey: versionKey,
          setActiveVersionKey: jest.fn(),
        };

        describe('default', () => {
          beforeEach(() => {
            createComponent({
              props: { version: mockVersionWithUpdate, itemType },
              provide: { projectId, groupId },
            });
          });

          it('shows the "View latest version" button', () => {
            expect(findPrimaryButtonText()).toEqual('View latest version');
          });

          it('does not show the "Update to vXX" or the "View enabled version" button', () => {
            expect(findSecondaryButtonText()).toBe(null);
          });

          it(`displays the ${namespace} update message for ${itemName}`, () => {
            expect(wrapper.text()).toContain(UPDATE_MESSAGES[namespace][itemName]);
          });
        });

        describe('when the user views the latest version', () => {
          beforeEach(() => {
            createComponent({
              props: {
                version: { ...mockVersionWithUpdate, activeVersionKey: VERSION_LATEST },
                itemType,
              },
              provide: { projectId, groupId },
            });
          });

          it('shows the "Update to vXX" button', () => {
            expect(findPrimaryButtonText()).toEqual('Update to v2.0.0');
          });

          it('shows the "View enabled version" button', () => {
            expect(findSecondaryButtonText()).toEqual('View enabled version');
          });

          describe('when the user updates to the latest version', () => {
            it('calls the update mutation with correct version prefix', async () => {
              await findAlert().vm.$emit('primaryAction');

              expect(mockUpdateAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
                input: {
                  id: mockConfiguration.id,
                  pinnedVersionPrefix: mockLatestVersion.versionName,
                },
              });
            });

            describe('when the request succeeds', () => {
              beforeEach(async () => {
                await findAlert().vm.$emit('primaryAction');
                await waitForPromises();
              });

              it(`shows success toast for ${itemName}`, () => {
                expect(mockToast.show).toHaveBeenCalledWith(SUCCESS_TOAST_MESSAGES[itemName]);
              });

              it(`resets the active version key to ${namespace === 'project' ? 'VERSION_PINNED' : 'VERSION_PINNED_GROUP'} for the next update`, () => {
                expect(mockVersionWithUpdate.setActiveVersionKey).toHaveBeenCalledWith(versionKey);
              });
            });

            describe('when the request succeeds but with errors', () => {
              it('emits an error message', async () => {
                mockUpdateAiCatalogItemConsumerHandler.mockResolvedValueOnce(
                  mockUpdateAiCatalogItemConsumerError,
                );
                await findAlert().vm.$emit('primaryAction');
                await waitForPromises();

                expect(wrapper.emitted('error')).toHaveLength(1);
                expect(wrapper.emitted('error')[0]).toEqual([
                  expect.objectContaining({
                    title: `Could not update ${itemName}.`,
                    errors: ['Some error'],
                  }),
                ]);
              });
            });

            describe('when the request fails', () => {
              it('emits an error message', async () => {
                mockUpdateAiCatalogItemConsumerHandler.mockRejectedValueOnce();
                await findAlert().vm.$emit('primaryAction');
                await waitForPromises();

                expect(wrapper.emitted('error')).toHaveLength(1);
                expect(wrapper.emitted('error')[0][0]).toEqual(
                  expect.objectContaining({
                    errors: expect.arrayContaining([
                      expect.stringContaining(`Could not update ${itemName}`),
                    ]),
                  }),
                );
              });
            });
          });
        });
      });
    });
  });
});
