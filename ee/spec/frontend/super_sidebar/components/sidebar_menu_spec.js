import Vue from 'vue';
import VueApollo from 'vue-apollo';
import superSidebarDataQuery from '~/super_sidebar/graphql/queries/super_sidebar.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SidebarMenu from '~/super_sidebar/components/sidebar_menu.vue';
import { sidebarData, sidebarDataCountResponse } from '../mock_data';

Vue.use(VueApollo);

describe('EE Sidebar Menu', () => {
  let wrapper;

  const successHandler = jest.fn().mockResolvedValue(sidebarDataCountResponse);

  const createWrapper = ({
    handler = successHandler,
    asyncSidebarCountsFlagEnabled = false,
    provide = {},
  }) => {
    wrapper = shallowMountExtended(SidebarMenu, {
      apolloProvider: createMockApollo([[superSidebarDataQuery, handler]]),
      propsData: {
        items: sidebarData.current_menu_items,
        isLoggedIn: sidebarData.is_logged_in,
        pinnedItemIds: sidebarData.pinned_items,
        panelType: sidebarData.panel_type,
        updatePinsUrl: sidebarData.update_pins_url,
      },
      provide: {
        glFeatures: {
          asyncSidebarCounts: asyncSidebarCountsFlagEnabled,
        },
        currentPath: 'group',
        ...provide,
      },
    });
  };

  const findMenuComponent = () => wrapper.findComponent(SidebarMenu);

  describe('Fetching async nav item pill count', () => {
    describe('when flag `asyncSidebarCounts` is disabled', () => {
      it('async sidebar count query is not called', async () => {
        createWrapper({
          asyncSidebarCountsFlagEnabled: false,
        });

        await waitForPromises();

        expect(findMenuComponent().exists()).toBe(true);
        expect(successHandler).not.toHaveBeenCalled();
      });
    });

    describe('when flag `asyncSidebarCounts` is enabled', () => {
      it('when there is no `currentPath` prop, the query is not called', async () => {
        createWrapper({
          provide: {
            currentPath: null,
          },
          asyncSidebarCountsFlagEnabled: true,
        });

        await waitForPromises();

        expect(findMenuComponent().exists()).toBe(true);
        expect(successHandler).not.toHaveBeenCalled();
      });

      it('when there is a `currentPath` prop, the query is called', async () => {
        createWrapper({
          asyncSidebarCountsFlagEnabled: true,
        });

        await waitForPromises();

        expect(findMenuComponent().exists()).toBe(true);
        expect(successHandler).toHaveBeenCalled();
      });
    });
  });
});
