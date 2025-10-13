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
    deleteFn: jest.fn(),
  };
  const routeParams = { id: '4' };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemActions, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: {
        $route: {
          params: routeParams,
        },
      },
    });
  };

  const findEditButton = () => wrapper.findByTestId('edit-button');
  const findTestButton = () => wrapper.findByTestId('test-button');
  const findAddToProjectButton = () => wrapper.findByTestId('add-to-project-button');
  const findMoreActions = () => wrapper.findByTestId('more-actions-dropdown');
  const findDuplicateButton = () => wrapper.findByTestId('duplicate-button');
  const findDeleteButton = () => wrapper.findByTestId('delete-button');

  describe.each`
    scenario                           | canAdmin | canUse   | editBtn  | testBtn  | addBtn   | moreActions | duplicateBtn | deleteBtn | itemType
    ${'not logged in'}                 | ${false} | ${false} | ${false} | ${false} | ${false} | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'not logged in'}                 | ${false} | ${false} | ${false} | ${false} | ${false} | ${false}    | ${false}     | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, not admin of item'}  | ${false} | ${true}  | ${false} | ${false} | ${true}  | ${true}     | ${true}      | ${false}  | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, admin of item'}      | ${true}  | ${true}  | ${true}  | ${true}  | ${true}  | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_AGENT}
    ${'logged in, admin of flow item'} | ${true}  | ${true}  | ${true}  | ${false} | ${true}  | ${true}     | ${true}      | ${true}   | ${AI_CATALOG_TYPE_FLOW}
  `(
    'when $scenario',
    ({
      canAdmin,
      canUse,
      editBtn,
      testBtn,
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
            },
            itemRoutes: {
              ...defaultProps.itemRoutes,
            },
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

      it(`${testBtn ? 'renders' : 'does not render'} Test button`, () => {
        expect(findTestButton().exists()).toBe(testBtn);
      });

      it(`${addBtn ? 'renders' : 'does not render'} "Add to project" button`, () => {
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
