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
    });
  };

  const findEditButton = () => wrapper.findByTestId('edit-button');
  const findDisableButton = () => wrapper.findByTestId('disable-button');
  const findAddToProjectButton = () => wrapper.findByTestId('add-to-project-button');
  const findAddToGroupButton = () => wrapper.findByTestId('add-to-group-button');
  const findMoreActions = () => wrapper.findByTestId('more-actions-dropdown');
  const findDuplicateButton = () => wrapper.findByTestId('duplicate-button');
  const findDeleteButton = () => wrapper.findByTestId('delete-button');

  describe.each`
    scenario                                              | canAdmin | canUse   | editBtn  | disableBtn | addBtn   | addGroupBtn | moreActions | duplicateBtn | deleteBtn | itemType                 | isGlobal | isEnabled
    ${'not logged in'}                                    | ${false} | ${false} | ${false} | ${false}   | ${false} | ${false}    | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT} | ${true}  | ${false}
    ${'not logged in, project level'}                     | ${false} | ${false} | ${false} | ${false}   | ${false} | ${false}    | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${false}
    ${'logged in, not admin of item'}                     | ${false} | ${true}  | ${false} | ${false}   | ${true}  | ${false}    | ${true}     | ${true}      | ${false}  | ${AI_CATALOG_TYPE_AGENT} | ${true}  | ${false}
    ${'logged in, admin of item'}                         | ${true}  | ${true}  | ${true}  | ${false}   | ${true}  | ${false}    | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT} | ${true}  | ${false}
    ${'logged in, admin of item, project level'}          | ${true}  | ${true}  | ${true}  | ${false}   | ${false} | ${false}    | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${false}
    ${'logged in, admin of item, project level, enabled'} | ${true}  | ${true}  | ${true}  | ${true}    | ${false} | ${false}    | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT} | ${false} | ${true}
    ${'logged in, admin of flow item'}                    | ${true}  | ${true}  | ${true}  | ${false}   | ${false} | ${true}     | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_FLOW}  | ${true}  | ${false}
  `(
    'when $scenario',
    ({
      canAdmin,
      canUse,
      editBtn,
      disableBtn,
      addBtn,
      addGroupBtn,
      moreActions,
      duplicateBtn,
      deleteBtn,
      itemType,
      isGlobal,
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
            isGlobal,
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

      it(`${addGroupBtn ? 'renders' : 'does not render'} "Enable in group" button`, () => {
        expect(findAddToGroupButton().exists()).toBe(addGroupBtn);
      });

      it(`${addBtn ? 'renders' : 'does not render'} "Enable in project" button`, () => {
        expect(findAddToProjectButton().exists()).toBe(addBtn);
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

      it(`${deleteBtn ? 'renders' : 'does not render'} Delete button`, () => {
        expect(findDeleteButton().exists()).toBe(deleteBtn);
      });
    },
  );
});
