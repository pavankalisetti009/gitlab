import Vue from 'vue';
import VueRouter from 'vue-router';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import YourWorkProjectsApp from '~/projects/your_work/components/app.vue';
import TabView from '~/projects/your_work/components/tab_view.vue';
import { createRouter } from '~/projects/your_work';
import { ROOT_ROUTE_NAME, INACTIVE_TAB } from 'ee/projects/your_work/constants';
import { stubComponent } from 'helpers/stub_component';

Vue.use(VueRouter);

const defaultRoute = {
  name: ROOT_ROUTE_NAME,
};

describe('YourWorkProjectsAppEE', () => {
  let wrapper;
  let router;

  const createComponent = ({ route = defaultRoute } = {}) => {
    router = createRouter();
    router.push(route);

    wrapper = mountExtended(YourWorkProjectsApp, {
      router,
      stubs: {
        TabView: stubComponent(TabView),
      },
    });
  };
  const findActiveTab = () => wrapper.findByRole('tab', { selected: true });

  afterEach(() => {
    router = null;
  });

  describe.each`
    name                  | expectedTab
    ${INACTIVE_TAB.value} | ${INACTIVE_TAB}
  `('onMount when route name is $name', ({ name, expectedTab }) => {
    beforeEach(() => {
      createComponent({ route: { name } });
    });

    it('initializes to the correct tab', () => {
      expect(findActiveTab().text()).toContain(expectedTab.text);
    });
  });
});
