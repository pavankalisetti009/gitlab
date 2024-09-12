import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlLoadingIcon } from '@gitlab/ui';
import getComplianceFrameworkQuery from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/graphql/get_compliance_framework.query.graphql';
import * as Utils from 'ee/groups/settings/compliance_frameworks/utils';
import EditFramework from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/edit_framework.vue';
import BasicInformationSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/basic_information_section.vue';
import PoliciesSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/policies_section.vue';
import ProjectsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/projects_section.vue';
import DeleteModal from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/delete_modal.vue';
import createComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/create_compliance_framework.mutation.graphql';
import updateComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/update_compliance_framework.mutation.graphql';
import deleteComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/delete_compliance_framework.mutation.graphql';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';

import {
  createComplianceFrameworksReportResponse,
  createComplianceFrameworkMutationResponse,
} from '../../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility');

describe('Edit Framework Form', () => {
  let wrapper;
  const propsData = {
    id: '1',
  };
  const provideData = {
    groupPath: 'group-1',
    pipelineConfigurationFullPathEnabled: true,
    pipelineConfigurationEnabled: true,
    disableScanPolicyUpdate: false,
    featureSecurityPoliciesEnabled: true,
    featurePipelineMaintenanceModeEnabled: true,
    migratePipelineToPolicyPath: '/migratepipelinetopolicypath',
    pipelineExecutionPolicyPath: '/policypath',
  };

  const showDeleteModal = jest.fn();
  const routerBack = jest.fn();
  const routerPush = jest.fn();

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findError = () => wrapper.findComponent(GlAlert);
  const findDeleteButton = () => wrapper.findByTestId('delete-btn');
  const findDeleteModal = () => wrapper.findComponent(DeleteModal);

  const invalidFeedback = (input) =>
    input.closest('[role=group]').querySelector('.invalid-feedback')?.textContent ?? '';

  function createComponent(
    mountFn = mountExtended,
    { requestHandlers = [], routeParams = { id: '1' }, provide = {} } = {},
  ) {
    return mountFn(EditFramework, {
      apolloProvider: createMockApollo(requestHandlers),
      provide: { ...provideData, ...provide },
      propsData,
      stubs: {
        ColorPicker: true,
        PoliciesSection: true,
        ProjectsSection: true,
        DeleteModal: stubComponent(DeleteModal, {
          template: '<div></div>',
          methods: { show: showDeleteModal },
        }),
      },
      mocks: {
        $route: {
          params: routeParams,
        },
        $router: {
          back: routerBack,
          push: routerPush,
        },
      },
    });
  }

  it('renders the loading icon', () => {
    wrapper = createComponent(shallowMountExtended);
    expect(findLoadingIcon().exists()).toBe(true);
  });

  it('renders error if loading fails', async () => {
    wrapper = createComponent(shallowMountExtended);

    await waitForPromises();
    expect(findError().exists()).toBe(true);
  });

  it('does not attempt to load framework if no id provided in url', async () => {
    const queryFn = jest.fn();
    wrapper = createComponent(shallowMountExtended, {
      requestHandlers: [[getComplianceFrameworkQuery, queryFn]],
      routeParams: {},
    });

    await waitForPromises();
    expect(queryFn).not.toHaveBeenCalled();
  });

  it('loads framework if id provided in url', async () => {
    wrapper = createComponent(mountExtended, {
      requestHandlers: [
        [
          getComplianceFrameworkQuery,
          () => ({ ...createComplianceFrameworksReportResponse(), default: true }),
        ],
      ],
    });

    await waitForPromises();
    const values = Object.fromEntries(new FormData(wrapper.find('form').element));

    expect(values).toStrictEqual({
      name: 'Some framework 1',
      description: 'This is a framework 1',
      pipeline_configuration_full_path: '',
      // JSDOM issue, checking manually:
      // default: true,
    });

    expect(wrapper.find('input[name="default"]').attributes('value')).toBe('true');
  });

  describe('Security policies migration', () => {
    it('passes hasMigratedPipeline prop to BasicInformationSection if relevant policy exists', async () => {
      wrapper = createComponent(mountExtended, {
        requestHandlers: [[getComplianceFrameworkQuery, createComplianceFrameworksReportResponse]],
        routeParams: { id: 1 },
      });

      await waitForPromises();
      expect(wrapper.findComponent(BasicInformationSection).props('hasMigratedPipeline')).toBe(
        true,
      );
    });

    it('does not pass hasMigratedPipeline prop to BasicInformationSection if relevant policy does not exists', async () => {
      wrapper = createComponent(mountExtended, {
        requestHandlers: [[getComplianceFrameworkQuery, createComplianceFrameworksReportResponse]],
        /* id: 2 does not have attached policy, only id: 1 has */
        routeParams: { id: 2 },
      });

      await waitForPromises();
      expect(wrapper.findComponent(BasicInformationSection).props('hasMigratedPipeline')).toBe(
        false,
      );
    });
  });

  describe('Validation', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('validates required fields', async () => {
      const nameInput = wrapper.findByLabelText('Name');
      const descriptionInput = wrapper.findByLabelText('Description');

      await nameInput.setValue('');
      await descriptionInput.setValue('');

      expect(invalidFeedback(nameInput.element)).toContain('is required');
      expect(invalidFeedback(descriptionInput.element)).toContain('is required');
    });

    it('validates length of name field', async () => {
      const nameInput = wrapper.findByLabelText('Name');

      await nameInput.setValue('a'.repeat(256));
      expect(invalidFeedback(nameInput.element)).toContain('less than 255');
    });

    it.each`
      pipelineConfigurationFullPath | message
      ${'foo.yml@bar/baz'}          | ${'Configuration not found'}
      ${'foobar'}                   | ${'Invalid format'}
    `(
      'sets the correct invalid message for pipeline',
      async ({ pipelineConfigurationFullPath, message }) => {
        jest.spyOn(Utils, 'fetchPipelineConfigurationFileExists').mockReturnValue(false);

        const pipelineInput = wrapper.findByLabelText(
          'Compliance pipeline configuration (optional)',
        );
        await pipelineInput.setValue(pipelineConfigurationFullPath);
        await waitForPromises();

        expect(invalidFeedback(pipelineInput.element)).toBe(message);
      },
    );
  });

  it.each`
    routeParams    | mutation                             | successHandler
    ${{}}          | ${createComplianceFrameworkMutation} | ${routerPush}
    ${{ id: '1' }} | ${updateComplianceFrameworkMutation} | ${routerBack}
  `('invokes correct mutation', async ({ routeParams, mutation, successHandler }) => {
    const mockResponse = (mutationType, namespace) =>
      jest
        .fn()
        .mockResolvedValue(createComplianceFrameworkMutationResponse(mutationType, namespace));
    const stubHandlers = [
      [createComplianceFrameworkMutation, mockResponse('createComplianceFramework', 'framework')],
      [
        updateComplianceFrameworkMutation,
        mockResponse('updateComplianceFramework', 'complianceFramework'),
      ],
    ];

    wrapper = createComponent(mountExtended, {
      requestHandlers: [
        [getComplianceFrameworkQuery, createComplianceFrameworksReportResponse],
        ...stubHandlers,
      ],
      routeParams,
    });
    await waitForPromises();

    const form = wrapper.find('form');
    await form.trigger('submit');
    await waitForPromises();
    expect(stubHandlers.find((handler) => handler[0] === mutation)[1]).toHaveBeenCalled();
    expect(successHandler).toHaveBeenCalled();
  });

  describe('Delete button', () => {
    it('does not render delete button if creating new framework', async () => {
      wrapper = createComponent(shallowMountExtended, { routeParams: {} });
      await waitForPromises();

      expect(findDeleteButton().exists()).toBe(false);
    });

    it('is disabled if there are linked policies', async () => {
      const response = createComplianceFrameworksReportResponse();
      response.data.namespace.complianceFrameworks.nodes[0].scanResultPolicies.pageInfo.startCursor =
        'MQ';
      wrapper = createComponent(shallowMountExtended, {
        requestHandlers: [[getComplianceFrameworkQuery, () => response]],
      });

      await waitForPromises();

      expect(findDeleteButton().props('disabled')).toBe(true);
    });

    it('is not disabled if there are no linked policies', async () => {
      wrapper = createComponent(shallowMountExtended);
      await waitForPromises();

      expect(findDeleteButton().props('disabled')).toBe(false);
    });

    it('renders delete button if editing existing framework', async () => {
      wrapper = createComponent();
      await waitForPromises();

      expect(findDeleteButton().exists()).toBe(true);
    });

    it('clicking delete button invokes modal', async () => {
      wrapper = createComponent(shallowMountExtended);
      await waitForPromises();

      findDeleteButton().vm.$emit('click');

      expect(showDeleteModal).toHaveBeenCalled();
    });

    describe('Delete mutation', () => {
      let resolveDeleteFrameworkMutation;
      const deleteFrameworkMutationFn = jest.fn().mockImplementation(
        () =>
          new Promise((resolve) => {
            resolveDeleteFrameworkMutation = resolve;
          }),
      );
      beforeEach(async () => {
        wrapper = createComponent(shallowMountExtended, {
          requestHandlers: [
            [
              getComplianceFrameworkQuery,
              () => ({ ...createComplianceFrameworksReportResponse(), default: true }),
            ],
            [deleteComplianceFrameworkMutation, deleteFrameworkMutationFn],
          ],
        });
        await waitForPromises();

        findDeleteModal().vm.$emit('delete');
        await waitForPromises();
      });

      it('invokes delete process and navigates back on success removal', async () => {
        expect(deleteFrameworkMutationFn).toHaveBeenCalled();

        resolveDeleteFrameworkMutation({ data: { destroyComplianceFramework: { errors: [] } } });
        await waitForPromises();

        expect(routerBack).toHaveBeenCalled();
      });

      it('invokes delete process and displays alert when mutation failed', async () => {
        const errorMessage = 'something went wrong';

        expect(deleteFrameworkMutationFn).toHaveBeenCalled();

        resolveDeleteFrameworkMutation({
          data: { destroyComplianceFramework: { errors: [errorMessage] } },
        });
        await waitForPromises();

        expect(findError().text()).toBe(errorMessage);
      });
    });
  });

  describe('Basic information section', () => {
    it('renders basic information section as expanded if creating new framework', async () => {
      wrapper = createComponent(shallowMountExtended, { routeParams: {} });
      await waitForPromises();
      expect(wrapper.findComponent(BasicInformationSection).props('isExpanded')).toBe(true);
    });

    it('renders basic information section as not expanded when editing', async () => {
      wrapper = createComponent(shallowMountExtended);
      await waitForPromises();
      expect(wrapper.findComponent(BasicInformationSection).props('isExpanded')).toBe(false);
    });
  });

  describe('Policies section', () => {
    it('does not render policies section if creating new framework', async () => {
      wrapper = createComponent(shallowMountExtended, { routeParams: {} });
      await waitForPromises();
      expect(wrapper.findComponent(PoliciesSection).exists()).toBe(false);
    });

    it('render policies section if editing framework', async () => {
      wrapper = createComponent(shallowMountExtended);
      await waitForPromises();
      expect(wrapper.findComponent(PoliciesSection).exists()).toBe(true);
    });

    it('does not render policies section if feature is disabled', async () => {
      wrapper = createComponent(shallowMountExtended, {
        provide: {
          featureSecurityPoliciesEnabled: false,
        },
      });
      await waitForPromises();
      expect(wrapper.findComponent(PoliciesSection).exists()).toBe(false);
    });
  });

  describe('Projects section', () => {
    it('does not render projects section if creating new framework', async () => {
      wrapper = createComponent(shallowMountExtended, { routeParams: {} });
      await waitForPromises();
      expect(wrapper.findComponent(ProjectsSection).exists()).toBe(false);
    });

    it('render projects section if editing framework', async () => {
      wrapper = createComponent(shallowMountExtended);
      await waitForPromises();
      expect(wrapper.findComponent(ProjectsSection).exists()).toBe(true);
    });
  });
});
