import { GlLoadingIcon, GlToast } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ComplianceViolationDetailsApp from 'ee/compliance_violations/components/compliance_violation_details_app.vue';
import { ComplianceViolationStatusDropdown } from 'ee/vue_shared/compliance';

Vue.use(VueApollo);
Vue.use(GlToast);

describe('ComplianceViolationDetailsApp', () => {
  let wrapper;
  let mockApollo;

  const violationId = '123';

  const mockComplianceViolationData = {
    id: violationId,
    status: 'in_review',
    project: {
      id: '2',
      nameWithNamespace: 'GitLab.org / GitLab Test',
      fullPath: '/gitlab/org/gitlab-test',
      webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
      __typename: 'Project',
    },
    __typename: 'ComplianceViolation',
  };

  const mockUpdateResponseData = {
    clientMutationId: 'test-id',
    errors: [],
    violation: {
      status: 'resolved',
      __typename: 'ComplianceViolation',
    },
    __typename: 'UpdateComplianceViolationStatusPayload',
  };

  const mockResolvers = ({
    shouldThrowQueryError = false,
    shouldThrowMutationError = false,
  } = {}) => ({
    Query: {
      complianceViolation: () => {
        if (shouldThrowQueryError) {
          throw new Error('Query error');
        }

        return mockComplianceViolationData;
      },
    },
    Mutation: {
      updateComplianceViolationStatus: () => {
        if (shouldThrowMutationError) {
          throw new Error('Mutation error');
        }

        return mockUpdateResponseData;
      },
    },
  });

  const createComponent = ({ props = {}, resolverOptions = {} } = {}) => {
    mockApollo = createMockApollo([], mockResolvers(resolverOptions));

    wrapper = shallowMountExtended(ComplianceViolationDetailsApp, {
      apolloProvider: mockApollo,
      propsData: {
        violationId,
        ...props,
      },
    });
  };

  const findLoadingStatus = () =>
    wrapper.findByTestId('compliance-violation-details-loading-status');
  const findStatusDropdown = () => wrapper.findComponent(ComplianceViolationStatusDropdown);
  const findViolationDetails = () => wrapper.findByTestId('compliance-violation-details');

  afterEach(() => {
    wrapper?.destroy();
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({
        mocks: {
          $apollo: {
            queries: {
              complianceViolation: {
                loading: true,
              },
            },
          },
        },
        data: {
          complianceViolation: null,
        },
      });
    });

    it('shows loading icon', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
      expect(findLoadingStatus().exists()).toBe(true);
    });

    it('does not show violation details', () => {
      expect(findViolationDetails().exists()).toBe(false);
    });
  });

  describe('when loaded with violation data', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not show loading icon', () => {
      expect(findLoadingStatus().exists()).toBe(false);
    });

    it('shows violation details', () => {
      expect(findViolationDetails().exists()).toBe(true);
    });

    it('displays the correct title', () => {
      const title = wrapper.findByTestId('compliance-violation-title');
      expect(title.text()).toBe(`Details of vio-${mockComplianceViolationData.id}`);
    });

    it('renders the status dropdown with correct props', () => {
      const dropdown = findStatusDropdown();
      expect(dropdown.exists()).toBe(true);
      expect(dropdown.props()).toMatchObject({
        value: 'in_review',
        loading: false,
      });
    });

    it('displays the project location with link', () => {
      const { project } = mockComplianceViolationData;
      const projectLink = wrapper.findByTestId('compliance-violation-location-link');
      expect(projectLink.exists()).toBe(true);
      expect(projectLink.text()).toBe(project.nameWithNamespace);
      expect(projectLink.attributes('href')).toBe(project.webUrl);
    });
  });

  describe('status update', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('calls mutation when status is changed', async () => {
      const mutationSpy = jest.spyOn(wrapper.vm.$apollo, 'mutate');

      findStatusDropdown().vm.$emit('change', 'resolved');
      await waitForPromises();

      expect(mutationSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: {
            input: {
              violationId,
              status: 'resolved',
            },
          },
        }),
      );
    });

    it('sets loading state during status update', async () => {
      const dropdown = findStatusDropdown();
      dropdown.vm.$emit('change', 'resolved');
      await nextTick();

      expect(dropdown.props('loading')).toBe(true);

      await waitForPromises();

      expect(dropdown.props('loading')).toBe(false);
    });

    it('shows error toast when mutation fails', async () => {
      createComponent({
        resolverOptions: { shouldThrowMutationError: true },
      });

      const mockToast = { show: jest.fn() };
      wrapper.vm.$toast = mockToast;

      await waitForPromises();

      findStatusDropdown().vm.$emit('change', 'resolved');
      await waitForPromises();

      expect(mockToast.show).toHaveBeenCalledWith(
        'Failed to update compliance violation status. Please try again later.',
        { variant: 'danger' },
      );
    });

    it('resets loading state even when mutation fails', async () => {
      createComponent({
        resolverOptions: { shouldThrowMutationError: true },
      });
      await waitForPromises();

      findStatusDropdown().vm.$emit('change', 'resolved');
      await waitForPromises();

      expect(wrapper.vm.isStatusUpdating).toBe(false);
    });
  });
});
