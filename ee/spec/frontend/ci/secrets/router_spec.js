import Vue from 'vue';
import VueRouter from 'vue-router';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SecretDetailsWrapper from 'ee/ci/secrets/components/secret_details/secret_details_wrapper.vue';
import SecretFormWrapper from 'ee/ci/secrets/components/secret_form/secret_form_wrapper.vue';
import SecretsTable from 'ee/ci/secrets/components/secrets_table/secrets_table.vue';
import createRouter from 'ee/ci/secrets/router';
import SecretsApp from 'ee//ci/secrets/components/secrets_app.vue';
import { getMatchedComponents } from '~/lib/utils/vue3compat/vue_router';

Vue.use(VueRouter);
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('Secrets router', () => {
  let wrapper;
  let router;

  const base = '/-/secrets';

  const groupProps = {
    groupId: '1',
    groupPath: '/path/to/group',
  };

  const projectProps = {
    projectId: '2',
    projectPath: '/path/to/project',
  };

  const editRoute = { name: 'edit', params: { secretName: 'SECRET_KEY' } };

  const createSecretsApp = async ({ route, props } = {}) => {
    router = createRouter(base, props);
    if (route) {
      await router.push(route);
    }

    wrapper = mountExtended(SecretsApp, {
      router,
      propsData: { ...props },
      data() {
        return {
          secrets: [],
        };
      },
      mocks: {
        $apollo: {
          queries: {
            environments: { loading: true },
            secrets: { loading: false },
          },
        },
      },
    });
  };

  it.each`
    path                     | componentNames            | components
    ${'/'}                   | ${'SecretsTable'}         | ${[SecretsTable]}
    ${'/?page=2'}            | ${'SecretsTable'}         | ${[SecretsTable]}
    ${'/new'}                | ${'SecretFormWrapper'}    | ${[SecretFormWrapper]}
    ${'/secretName/details'} | ${'SecretDetailsWrapper'} | ${[SecretDetailsWrapper]}
    ${'/secretName/edit'}    | ${'SecretFormWrapper'}    | ${[SecretFormWrapper]}
  `('uses $componentNames for path "$path"', ({ path, components }) => {
    router = createRouter(base, groupProps);
    const componentsForRoute = getMatchedComponents(router, path);

    expect(componentsForRoute).toStrictEqual(components);
  });

  it.each`
    path                          | redirect
    ${'/secretName'}              | ${'details'}
    ${'/secretName/unknownroute'} | ${'index'}
  `('redirects from $path to $redirect', async ({ path, redirect }) => {
    router = createRouter(base, groupProps);

    await router.push(path);

    expect(router.currentRoute.name).toBe(redirect);
  });

  describe.each`
    entity       | props           | fullPath
    ${'group'}   | ${groupProps}   | ${groupProps.groupPath}
    ${'project'} | ${projectProps} | ${projectProps.projectPath}
  `('$entity secrets form', ({ props, fullPath }) => {
    it('provides the correct props when visiting the index', async () => {
      await createSecretsApp({ route: '/', props });

      expect(wrapper.findComponent(SecretsTable).props()).toMatchObject({
        fullPath,
      });
    });

    it('provides the correct props when visiting the create form', async () => {
      await createSecretsApp({ route: '/new', props });

      expect(wrapper.findComponent(SecretFormWrapper).props()).toMatchObject({
        fullPath,
      });
    });

    it('provides the correct props when visiting the edit form', async () => {
      await createSecretsApp({ route: editRoute, props });

      expect(wrapper.findComponent(SecretFormWrapper).props()).toMatchObject({
        fullPath,
        isEditing: true,
        secretName: 'SECRET_KEY',
      });
    });
  });
});
