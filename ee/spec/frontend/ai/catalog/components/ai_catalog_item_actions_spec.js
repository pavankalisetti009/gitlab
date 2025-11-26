import { nextTick } from 'vue';
import { GlModal, GlFormRadioGroup } from '@gitlab/ui';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogItemActions from 'ee/ai/catalog/components/ai_catalog_item_actions.vue';
import { AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_AGENT } from 'ee/ai/catalog/constants';
import { mockAgent } from '../mock_data';

jest.mock('~/lib/utils/common_utils');

describe('AiCatalogItemActions', () => {
  let wrapper;

  const defaultProps = {
    item: mockAgent,
    itemRoutes: {
      duplicate: '/items/:id/duplicate',
      edit: '/items/:id/edit',
      run: '/items/:id/run',
    },
    isAgentsAvailable: true,
    isFlowsAvailable: true,
    deleteFn: jest.fn(),
  };
  const routeParams = { id: '4' };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemActions, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide,
      mocks: {
        $route: {
          params: routeParams,
        },
      },
      stubs: { GlModal },
    });
  };

  const findEditButton = () => wrapper.findByTestId('edit-button');
  const findDisableButton = () => wrapper.findByTestId('disable-button');
  const findEnableButton = () => wrapper.findByTestId('enable-button');
  const findAddToProjectButton = () => wrapper.findByTestId('add-to-project-button');
  const findAddToGroupButton = () => wrapper.findByTestId('add-to-group-button');
  const findMoreActions = () => wrapper.findByTestId('more-actions-dropdown');
  const findDuplicateButton = () => wrapper.findByTestId('duplicate-button');
  const findReportButton = () => wrapper.findByTestId('report-button');
  const findDeleteButton = () => wrapper.findByTestId('delete-button');
  const findDeleteModal = () => wrapper.findByTestId('delete-item-modal');

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

  describe.each`
    scenario                           | canAdmin | canUse   | editBtn  | disableBtn | enableBtn | addBtn   | moreActions | duplicateBtn | deleteBtn | itemType
    ${'not logged in'}                 | ${false} | ${false} | ${false} | ${false}   | ${false}  | ${false} | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, not admin of item'}  | ${false} | ${true}  | ${false} | ${false}   | ${false}  | ${true}  | ${true}     | ${true}      | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, admin of item'}      | ${true}  | ${true}  | ${true}  | ${false}   | ${false}  | ${true}  | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, admin of flow item'} | ${true}  | ${true}  | ${true}  | ${false}   | ${false}  | ${true}  | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_FLOW}
  `(
    'at the Explore level, when $scenario',
    ({
      canAdmin,
      canUse,
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

      it('does not render "Enable in project" button', () => {
        expect(findAddToProjectButton().exists()).toBe(false);
      });

      it(`${moreActions ? 'renders' : 'does not render'} more actions`, () => {
        expect(findMoreActions().exists()).toBe(moreActions);
      });

      it(`${duplicateBtn ? 'renders' : 'does not render'} Duplicate button`, () => {
        expect(findDuplicateButton().exists()).toBe(duplicateBtn);
        if (duplicateBtn) {
          expect(findDuplicateButton().props('item')).toMatchObject({
            to: {
              name: defaultProps.itemRoutes.duplicate,
              params: { id: routeParams.id },
            },
          });
        }
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
      beforeEach(() => {
        createComponent({
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

      it('does not render "Enable in group" button', () => {
        expect(findAddToGroupButton().exists()).toBe(false);
      });

      it('does not render "Enable in project" button', () => {
        expect(findAddToProjectButton().exists()).toBe(false);
      });

      it(`${moreActions ? 'renders' : 'does not render'} more actions`, () => {
        expect(findMoreActions().exists()).toBe(moreActions);
      });

      it(`${duplicateBtn ? 'renders' : 'does not render'} Duplicate button`, () => {
        expect(findDuplicateButton().exists()).toBe(duplicateBtn);
        if (duplicateBtn) {
          expect(findDuplicateButton().props('item')).toMatchObject({
            to: {
              name: defaultProps.itemRoutes.duplicate,
              params: { id: routeParams.id },
            },
          });
        }
      });

      it('does not render Report button', () => {
        expect(findReportButton().exists()).toBe(false);
      });

      it(`${deleteBtn ? 'renders' : 'does not render'} Delete button`, () => {
        expect(findDeleteButton().exists()).toBe(deleteBtn);
      });
    },
  );

  describe('when isAgentsAvailable and isFlowsAvailable are false', () => {
    beforeEach(() => {
      isLoggedIn.mockReturnValue(true);

      createComponent({
        provide: {
          isGlobal: true,
        },
        props: {
          isAgentsAvailable: false,
          isFlowsAvailable: false,
        },
      });
    });

    it('renders "Enable in project" button', () => {
      expect(findAddToProjectButton().exists()).toBe(true);
    });

    it('does not render "Enable in group" button', () => {
      expect(findAddToGroupButton().exists()).toBe(false);
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
        findDeleteButton().vm.$emit('action');

        await nextTick();

        expect(findDeleteModal().exists()).toBe(true);
        expect(findDeleteModal().findComponent(GlFormRadioGroup).exists()).toBe(true);
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
        findDeleteButton().vm.$emit('action');

        await nextTick();

        expect(findDeleteModal().findComponent(GlFormRadioGroup).exists()).toBe(false);
      });
    });
  });
});
