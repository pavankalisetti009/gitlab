import VueRouter from 'vue-router';
import Vue, { nextTick } from 'vue';
import createRouter from 'ee/ci/secrets/router';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SecretsApp from 'ee/ci/secrets/components/secrets_app.vue';

describe('SecretsApp', () => {
  let wrapper;

  const groupProps = { groupPath: '/path/to/group', groupId: '123' };
  const projectProps = { projectPath: '/path/to/project', projectId: '123' };

  Vue.use(VueRouter);
  const mockToastShow = jest.fn();

  const findRouterView = () => wrapper.findComponent({ ref: 'router-view' });

  const createComponent = ({ props, stubs, router } = {}) => {
    wrapper = mountExtended(SecretsApp, {
      router,
      propsData: { ...props },
      stubs,
      mocks: {
        $toast: { show: mockToastShow },
      },
    });
  };

  describe.each`
    entity       | props
    ${'group'}   | ${groupProps}
    ${'project'} | ${projectProps}
  `('$entity secrets app', ({ props }) => {
    it('renders the secrets app', () => {
      createComponent({ props, stubs: { RouterView: true } });

      expect(wrapper.findComponent(SecretsApp).exists()).toBe(true);
    });

    it('renders the router view', () => {
      createComponent({ props, stubs: { RouterView: true } });

      expect(findRouterView().exists()).toBe(true);
    });
  });

  describe('toast message', () => {
    beforeEach(() => {
      createComponent({
        router: createRouter('/-/secrets', { ...projectProps }),
        props: projectProps,
      });
    });

    it('renders toast message when show-secrets-toast is emitted', async () => {
      findRouterView().vm.$emit('show-secrets-toast', 'This is a toast message.');
      await nextTick();

      expect(mockToastShow).toHaveBeenCalledWith('This is a toast message.');
    });
  });
});
