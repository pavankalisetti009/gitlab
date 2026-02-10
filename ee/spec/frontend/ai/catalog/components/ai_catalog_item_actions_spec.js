import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlFormRadioGroup, GlTooltip } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogItemActions from 'ee/ai/catalog/components/ai_catalog_item_actions.vue';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import {
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  TRACK_EVENT_ENABLE_AI_CATALOG_ITEM,
  TRACK_EVENT_DISABLE_AI_CATALOG_ITEM,
  TRACK_EVENT_DELETE_AI_CATALOG_ITEM,
  TRACK_EVENT_DUPLICATE_AI_CATALOG_ITEM,
  TRACK_EVENT_ITEM_TYPES,
  TRACK_EVENT_ORIGIN_EXPLORE,
  TRACK_EVENT_ORIGIN_PROJECT,
  TRACK_EVENT_PAGE_SHOW,
} from 'ee/ai/catalog/constants';
import {
  mockAgent,
  mockProjectUserPermissionsResponse,
  mockProjectUserPermissionsNotAdminResponse,
} from '../mock_data';

jest.mock('~/lib/utils/common_utils');

Vue.use(VueApollo);

describe('AiCatalogItemActions', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    item: mockAgent,
    itemRoutes: {
      duplicate: '/items/:id/duplicate',
      edit: '/items/:id/edit',
      run: '/items/:id/run',
    },
    deleteFn: jest.fn(),
    enableModalTexts: {
      title: 'Enable flow from group',
      dropdownTexts: {},
    },
  };
  const routeParams = { id: '4' };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const mockProjectUserPermissionsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockProjectUserPermissionsResponse);
  const mockProjectUserPermissionsNotAdminQueryHandler = jest
    .fn()
    .mockResolvedValue(mockProjectUserPermissionsNotAdminResponse);

  const createComponent = ({
    props = {},
    provide = {},
    projectUserPermissionsHandler = mockProjectUserPermissionsQueryHandler,
    glAbilities = {},
    glFeatures = {},
  } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogProjectUserPermissionsQuery, projectUserPermissionsHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogItemActions, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide,
      mocks: {
        $route: {
          params: routeParams,
        },
        $router: {
          push: jest.fn(),
        },
        glAbilities,
        glFeatures,
      },
      stubs: { GlModal },
    });
  };

  const findEditButton = () => wrapper.findByTestId('edit-button');
  const findDisableButton = () => wrapper.findByTestId('disable-button');
  const findEnableButton = () => wrapper.findByTestId('enable-button');
  const findAddToGroupButton = () => wrapper.findByTestId('add-to-group-button');
  const findMoreActions = () => wrapper.findByTestId('more-actions-dropdown');
  const findDuplicateButton = () => wrapper.findByTestId('duplicate-button');
  const findReportButton = () => wrapper.findByTestId('report-button');
  const findDeleteButton = () => wrapper.findByTestId('delete-button');
  const findDeleteModal = () => wrapper.findByTestId('delete-item-modal');
  const findDropdownTooltip = () => wrapper.findComponent(GlTooltip);

  const openDeleteModal = async () => {
    findDeleteButton().vm.$emit('action');
    await nextTick();
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders "More actions" tooltip', () => {
      expect(findDropdownTooltip().text()).toBe('More actions');
    });
  });

  describe('when user can report item', () => {
    beforeEach(() => {
      createComponent({
        props: {
          item: {
            ...mockAgent,
            userPermissions: {
              reportAiCatalogItem: true,
            },
          },
        },
      });
    });

    it('renders Report button', () => {
      expect(findReportButton().exists()).toBe(true);
    });
  });

  describe('at the Explore level', () => {
    beforeEach(async () => {
      createComponent({ provide: { isGlobal: true } });
      await waitForPromises();
    });

    it('does not fetch project permissions', () => {
      expect(mockProjectUserPermissionsQueryHandler).not.toHaveBeenCalled();
    });
  });

  describe('at the Project level', () => {
    beforeEach(async () => {
      createComponent({ provide: { isGlobal: false, projectPath: 'gitlab-duo/test' } });
      await waitForPromises();
    });

    it('fetched project permissions', () => {
      expect(mockProjectUserPermissionsQueryHandler).toHaveBeenCalled();
    });
  });

  describe.each`
    scenario                                 | canAdmin | canUse   | foundational | editBtn  | disableBtn | enableBtn | addBtn   | moreActions | duplicateBtn | deleteBtn | itemType
    ${'not logged in'}                       | ${false} | ${false} | ${false}     | ${false} | ${false}   | ${false}  | ${false} | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, not admin of item'}        | ${false} | ${true}  | ${false}     | ${false} | ${false}   | ${false}  | ${true}  | ${true}     | ${true}      | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, admin of item'}            | ${true}  | ${true}  | ${false}     | ${true}  | ${false}   | ${false}  | ${true}  | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, admin of flow item'}       | ${true}  | ${true}  | ${false}     | ${true}  | ${false}   | ${false}  | ${true}  | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_FLOW}
    ${'logged in, foundational agent'}       | ${false} | ${true}  | ${true}      | ${false} | ${false}   | ${false}  | ${false} | ${true}     | ${true}      | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, admin foundational agent'} | ${true}  | ${true}  | ${true}      | ${true}  | ${false}   | ${false}  | ${false} | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT}
  `(
    'at the Explore level, when $scenario',
    ({
      canAdmin,
      canUse,
      foundational,
      editBtn,
      disableBtn,
      enableBtn,
      addBtn,
      moreActions,
      duplicateBtn,
      deleteBtn,
      itemType,
    }) => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              itemType,
              foundational,
              userPermissions: {
                adminAiCatalogItem: canAdmin,
              },
              configurationForProject: {
                id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
              },
            },
            itemRoutes: {
              ...defaultProps.itemRoutes,
            },
          },
          provide: {
            isGlobal: true,
          },
        });
        isLoggedIn.mockReturnValue(canUse);
      });

      it(`${editBtn ? 'renders' : 'does not render'} Edit button`, () => {
        expect(findEditButton().exists()).toBe(editBtn);
        if (editBtn) {
          expect(findEditButton().props('to')).toMatchObject({
            name: defaultProps.itemRoutes.edit,
            params: { id: routeParams.id },
          });
        }
      });

      it(`${disableBtn ? 'renders' : 'does not render'} "Disable" button`, () => {
        expect(findDisableButton().exists()).toBe(disableBtn);
      });

      it(`${enableBtn ? 'renders' : 'does not render'} "Enable" button`, () => {
        expect(findEnableButton().exists()).toBe(enableBtn);
      });

      it(`${addBtn ? 'renders' : 'does not render'} "Enable in group" button`, () => {
        expect(findAddToGroupButton().exists()).toBe(addBtn);
      });

      it(`${moreActions ? 'renders' : 'does not render'} more actions`, () => {
        expect(findMoreActions().exists()).toBe(moreActions);
      });

      it(`${duplicateBtn ? 'renders' : 'does not render'} Duplicate button`, () => {
        expect(findDuplicateButton().exists()).toBe(duplicateBtn);
      });

      it('does not render Report button', () => {
        expect(findReportButton().exists()).toBe(false);
      });

      it(`${deleteBtn ? 'renders' : 'does not render'} Delete button`, () => {
        expect(findDeleteButton().exists()).toBe(deleteBtn);
      });
    },
  );

  describe.each`
    scenario                              | canAdmin | canUse   | editBtn  | disableBtn | enableBtn | moreActions | duplicateBtn | deleteBtn | itemType                 | isGlobal | isEnabled
    ${'not logged in'}                    | ${false} | ${false} | ${false} | ${false}   | ${false}  | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${false}
    ${'logged in, not admin of item'}     | ${false} | ${true}  | ${false} | ${false}   | ${false}  | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${true}
    ${'logged in, admin of item'}         | ${true}  | ${true}  | ${true}  | ${false}   | ${true}   | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${false}
    ${'logged in, admin of enabled item'} | ${true}  | ${true}  | ${true}  | ${true}    | ${false}  | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${true}
    ${'logged in, admin of flow item'}    | ${true}  | ${true}  | ${true}  | ${true}    | ${false}  | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_FLOW}  | ${false} | ${true}
  `(
    'at the Project level, when $scenario',
    ({
      canAdmin,
      canUse,
      editBtn,
      disableBtn,
      enableBtn,
      moreActions,
      duplicateBtn,
      deleteBtn,
      itemType,
      isEnabled,
    }) => {
      beforeEach(async () => {
        const permissionsHandler = canAdmin
          ? mockProjectUserPermissionsQueryHandler
          : mockProjectUserPermissionsNotAdminQueryHandler;
        createComponent({
          projectUserPermissionsHandler: permissionsHandler,
          props: {
            item: {
              ...mockAgent,
              itemType,
              userPermissions: {
                adminAiCatalogItem: canAdmin,
              },
              configurationForProject: {
                id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                enabled: isEnabled,
              },
            },
            itemRoutes: {
              ...defaultProps.itemRoutes,
            },
          },
          provide: {
            isGlobal: false,
            projectPath: 'gitlab-duo/test',
          },
        });
        isLoggedIn.mockReturnValue(canUse);

        await waitForPromises();
      });

      it(`${editBtn ? 'renders' : 'does not render'} Edit button`, () => {
        expect(findEditButton().exists()).toBe(editBtn);
        if (editBtn) {
          expect(findEditButton().props('to')).toMatchObject({
            name: defaultProps.itemRoutes.edit,
            params: { id: routeParams.id },
          });
        }
      });

      it(`${disableBtn ? 'renders' : 'does not render'} "Disable" button`, () => {
        expect(findDisableButton().exists()).toBe(disableBtn);
      });

      it(`${enableBtn ? 'renders' : 'does not render'} "Enable" button`, () => {
        expect(findEnableButton().exists()).toBe(enableBtn);
      });

      it('does not render "Enable in group" button', () => {
        expect(findAddToGroupButton().exists()).toBe(false);
      });

      it(`${moreActions ? 'renders' : 'does not render'} more actions`, () => {
        expect(findMoreActions().exists()).toBe(moreActions);
      });

      it(`${duplicateBtn ? 'renders' : 'does not render'} Duplicate button`, () => {
        expect(findDuplicateButton().exists()).toBe(duplicateBtn);
      });

      it('does not render Report button', () => {
        expect(findReportButton().exists()).toBe(false);
      });

      it(`${deleteBtn ? 'renders' : 'does not render'} Delete button`, () => {
        expect(findDeleteButton().exists()).toBe(deleteBtn);
      });
    },
  );

  describe('at Project level', () => {
    describe('when hasParentConsumer is false', () => {
      beforeEach(async () => {
        isLoggedIn.mockReturnValue(true);
        createComponent({
          provide: {
            isGlobal: false,
            projectPath: 'gitlab-duo/test',
          },
          props: {
            hasParentConsumer: false,
          },
        });
        await waitForPromises();
      });

      it('disables the "Enable" button', () => {
        expect(findEnableButton().props('disabled')).toBe(true);
      });
    });

    describe('when hasParentConsumer is true', () => {
      beforeEach(async () => {
        isLoggedIn.mockReturnValue(true);
        createComponent({
          provide: {
            isGlobal: false,
            projectPath: 'gitlab-duo/test',
          },
          props: {
            hasParentConsumer: true,
          },
        });
        await waitForPromises();
      });

      it('does not disable the "Enable" button', () => {
        expect(findEnableButton().props('disabled')).toBe(false);
      });
    });
  });

  describe('delete modal', () => {
    describe('when user can hard delete', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              userPermissions: {
                adminAiCatalogItem: true,
                forceHardDeleteAiCatalogItem: true,
              },
            },
          },
        });
      });

      it('displays deletion method radio buttons', async () => {
        await openDeleteModal();

        expect(findDeleteModal().exists()).toBe(true);
        expect(findDeleteModal().findComponent(GlFormRadioGroup).exists()).toBe(true);
      });

      it('displays deletion method radio buttons with hard delete option selected', async () => {
        await openDeleteModal();

        const radioGroup = findDeleteModal().findComponent(GlFormRadioGroup);
        expect(radioGroup.attributes('checked')).toBe('true');
      });

      it('calls deleteFn with forceHardDelete set to true if hard delete is selected', async () => {
        await openDeleteModal();

        const deleteModal = findDeleteModal();
        const radioGroup = deleteModal.findComponent(GlFormRadioGroup);
        radioGroup.vm.$emit('input', true);

        await nextTick();

        const actionFn = deleteModal.props('actionFn');
        await actionFn();

        expect(defaultProps.deleteFn).toHaveBeenCalledWith(true);
      });

      it('calls deleteFn with forceHardDelete set to false if soft delete is selected', async () => {
        await openDeleteModal();

        const deleteModal = findDeleteModal();
        const radioGroup = deleteModal.findComponent(GlFormRadioGroup);
        radioGroup.vm.$emit('input', false);

        await nextTick();

        const actionFn = deleteModal.props('actionFn');
        await actionFn();

        expect(defaultProps.deleteFn).toHaveBeenCalledWith(false);
      });
    });

    describe('when user cannot hard delete', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              userPermissions: {
                adminAiCatalogItem: true,
                forceHardDeleteAiCatalogItem: false,
              },
            },
          },
        });
      });

      it('does not display deletion method radio buttons', async () => {
        await openDeleteModal();

        expect(findDeleteModal().findComponent(GlFormRadioGroup).exists()).toBe(false);
      });

      it('calls deleteFn with forceHardDelete set to false', async () => {
        await openDeleteModal();

        const deleteModal = findDeleteModal();
        const actionFn = deleteModal.props('actionFn');
        await actionFn();

        expect(defaultProps.deleteFn).toHaveBeenCalledWith(false);
      });
    });
  });

  describe('tracking', () => {
    describe.each`
      scenario                                       | itemType                 | isGlobal | isEnabled | hasParentConsumer | buttonFinder            | expectedOrigin
      ${'Enable agent at Explore level'}             | ${AI_CATALOG_TYPE_AGENT} | ${true}  | ${false}  | ${false}          | ${findAddToGroupButton} | ${TRACK_EVENT_ORIGIN_EXPLORE}
      ${'Enable flow at Project level'}              | ${AI_CATALOG_TYPE_FLOW}  | ${false} | ${false}  | ${false}          | ${findEnableButton}     | ${TRACK_EVENT_ORIGIN_PROJECT}
      ${'Enable agent at Project level with parent'} | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${false}  | ${true}           | ${findEnableButton}     | ${TRACK_EVENT_ORIGIN_PROJECT}
    `(
      'when clicking $scenario',
      ({ itemType, isGlobal, isEnabled, hasParentConsumer, buttonFinder, expectedOrigin }) => {
        beforeEach(async () => {
          isLoggedIn.mockReturnValue(true);
          createComponent({
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: true,
                },
                configurationForProject: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                  enabled: isEnabled,
                },
              },
              hasParentConsumer,
            },
            provide: {
              isGlobal,
              projectPath: 'gitlab-duo/test',
            },
          });
          await waitForPromises();
        });

        it(`tracks event  ${TRACK_EVENT_ENABLE_AI_CATALOG_ITEM} with correct properties`, async () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          await buttonFinder().vm.$emit('click');

          await nextTick();

          expect(trackEventSpy).toHaveBeenCalledWith(
            TRACK_EVENT_ENABLE_AI_CATALOG_ITEM,
            {
              label: TRACK_EVENT_ITEM_TYPES[itemType],
              origin: expectedOrigin,
              page: TRACK_EVENT_PAGE_SHOW,
            },
            undefined,
          );
        });
      },
    );

    describe.each`
      scenario                            | itemType                 | isGlobal | isEnabled | buttonFinder         | expectedOrigin                | projectPath
      ${'Disable agent at Project level'} | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${true}   | ${findDisableButton} | ${TRACK_EVENT_ORIGIN_PROJECT} | ${'gitlab-duo/test'}
      ${'Disable flow at Project level'}  | ${AI_CATALOG_TYPE_FLOW}  | ${false} | ${true}   | ${findDisableButton} | ${TRACK_EVENT_ORIGIN_PROJECT} | ${'gitlab-duo/test'}
    `(
      'when clicking $scenario',
      ({ itemType, isGlobal, isEnabled, buttonFinder, expectedOrigin, projectPath }) => {
        beforeEach(async () => {
          isLoggedIn.mockReturnValue(true);
          createComponent({
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: true,
                },
                configurationForProject: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                  enabled: isEnabled,
                },
              },
              disableConfirmMessage: 'Are you sure you want to disable this agent?',
            },
            provide: {
              isGlobal,
              projectPath,
            },
          });
          await waitForPromises();
        });

        it(`tracks event  ${TRACK_EVENT_DISABLE_AI_CATALOG_ITEM} with correct properties`, async () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          await buttonFinder().vm.$emit('action');

          await nextTick();

          expect(trackEventSpy).toHaveBeenCalledWith(
            TRACK_EVENT_DISABLE_AI_CATALOG_ITEM,
            {
              label: TRACK_EVENT_ITEM_TYPES[itemType],
              origin: expectedOrigin,
              page: TRACK_EVENT_PAGE_SHOW,
            },
            undefined,
          );
        });
      },
    );

    describe.each`
      scenario                           | itemType                 | isGlobal | isEnabled | buttonFinder        | expectedOrigin
      ${'Delete agent at Explore level'} | ${AI_CATALOG_TYPE_AGENT} | ${true}  | ${false}  | ${findDeleteButton} | ${TRACK_EVENT_ORIGIN_EXPLORE}
      ${'Delete flow at Project level'}  | ${AI_CATALOG_TYPE_FLOW}  | ${false} | ${false}  | ${findDeleteButton} | ${TRACK_EVENT_ORIGIN_PROJECT}
      ${'Delete agent at Project level'} | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${false}  | ${findDeleteButton} | ${TRACK_EVENT_ORIGIN_PROJECT}
    `(
      'when clicking $scenario',
      ({ itemType, isGlobal, isEnabled, buttonFinder, expectedOrigin }) => {
        beforeEach(async () => {
          isLoggedIn.mockReturnValue(true);
          createComponent({
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: true,
                },
                configurationForProject: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                  enabled: isEnabled,
                },
              },
            },
            provide: {
              isGlobal,
              projectPath: isGlobal ? undefined : 'gitlab-duo/test',
            },
          });
          await waitForPromises();
        });

        it(`tracks event  ${TRACK_EVENT_DELETE_AI_CATALOG_ITEM} with correct properties`, async () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          await buttonFinder().vm.$emit('action');

          await nextTick();

          expect(trackEventSpy).toHaveBeenCalledWith(
            TRACK_EVENT_DELETE_AI_CATALOG_ITEM,
            {
              label: TRACK_EVENT_ITEM_TYPES[itemType],
              origin: expectedOrigin,
              page: TRACK_EVENT_PAGE_SHOW,
            },
            undefined,
          );
        });
      },
    );

    describe.each`
      scenario                              | itemType                 | isGlobal | isEnabled | buttonFinder           | expectedOrigin
      ${'Duplicate agent at Explore level'} | ${AI_CATALOG_TYPE_AGENT} | ${true}  | ${false}  | ${findDuplicateButton} | ${TRACK_EVENT_ORIGIN_EXPLORE}
      ${'Duplicate flow at Project level'}  | ${AI_CATALOG_TYPE_FLOW}  | ${false} | ${false}  | ${findDuplicateButton} | ${TRACK_EVENT_ORIGIN_PROJECT}
      ${'Duplicate agent at Project level'} | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${false}  | ${findDuplicateButton} | ${TRACK_EVENT_ORIGIN_PROJECT}
    `(
      'when clicking $scenario',
      ({ itemType, isGlobal, isEnabled, buttonFinder, expectedOrigin }) => {
        beforeEach(async () => {
          isLoggedIn.mockReturnValue(true);
          createComponent({
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: true,
                },
                configurationForProject: {
                  id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
                  enabled: isEnabled,
                },
              },
            },
            provide: {
              isGlobal,
              projectPath: isGlobal ? undefined : 'gitlab-duo/test',
            },
          });
          await waitForPromises();
        });

        it(`tracks event  ${TRACK_EVENT_DUPLICATE_AI_CATALOG_ITEM} with correct properties`, async () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          await buttonFinder().vm.$emit('action');

          await nextTick();

          expect(trackEventSpy).toHaveBeenCalledWith(
            TRACK_EVENT_DUPLICATE_AI_CATALOG_ITEM,
            {
              label: TRACK_EVENT_ITEM_TYPES[itemType],
              origin: expectedOrigin,
              page: TRACK_EVENT_PAGE_SHOW,
            },
            undefined,
          );
        });
      },
    );
  });

  describe('third-party flow duplicate button visibility', () => {
    describe.each`
      scenario                                                 | itemType                            | glAbility | aiCatalogThirdPartyFlows | aiCatalogCreateThirdPartyFlows | shouldRender
      ${'THIRD_PARTY_FLOW with ability enabled'}               | ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${true}   | ${false}                 | ${false}                       | ${true}
      ${'THIRD_PARTY_FLOW with feature flags enabled'}         | ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${null}   | ${true}                  | ${true}                        | ${true}
      ${'THIRD_PARTY_FLOW with feature not available'}         | ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${false}  | ${false}                 | ${false}                       | ${false}
      ${'THIRD_PARTY_FLOW with only one feature flag enabled'} | ${AI_CATALOG_TYPE_THIRD_PARTY_FLOW} | ${null}   | ${true}                  | ${false}                       | ${false}
      ${'non-THIRD_PARTY_FLOW with feature not available'}     | ${AI_CATALOG_TYPE_AGENT}            | ${false}  | ${false}                 | ${false}                       | ${true}
    `(
      'when $scenario',
      ({
        itemType,
        glAbility,
        aiCatalogThirdPartyFlows,
        aiCatalogCreateThirdPartyFlows,
        shouldRender,
      }) => {
        beforeEach(() => {
          isLoggedIn.mockReturnValue(true);
          createComponent({
            props: {
              item: {
                ...mockAgent,
                itemType,
                userPermissions: {
                  adminAiCatalogItem: true,
                },
              },
            },
            provide: {
              isGlobal: true,
              glAbilities: {
                createAiCatalogThirdPartyFlow: glAbility,
              },
              glFeatures: {
                aiCatalogThirdPartyFlows,
                aiCatalogCreateThirdPartyFlows,
              },
            },
          });
        });

        it(`${shouldRender ? 'renders' : 'does not render'} Duplicate button`, () => {
          expect(findDuplicateButton().exists()).toBe(shouldRender);
        });
      },
    );
  });
});
