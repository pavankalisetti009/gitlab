import { GlLoadingIcon, GlToast } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ComplianceViolationDetailsApp from 'ee/compliance_violations/components/compliance_violation_details_app.vue';
import AuditEvent from 'ee/compliance_violations/components/audit_event.vue';
import ViolationSection from 'ee/compliance_violations/components/violation_section.vue';
import { ComplianceViolationStatusDropdown } from 'ee/vue_shared/compliance';

Vue.use(VueApollo);
Vue.use(GlToast);

describe('ComplianceViolationDetailsApp', () => {
  let wrapper;
  let mockApollo;

  const violationId = '123';
  const complianceCenterPath = 'mock/compliance-center';

  const mockComplianceViolationData = {
    id: `gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/${violationId}`,
    status: 'IN_REVIEW',
    createdAt: '2025-06-16T02:20:41Z',
    complianceControl: {
      name: 'Merge request controls',
      complianceRequirement: {
        name: 'basic code regulation',
        framework: {
          id: 'gid://gitlab/ComplianceManagement::Framework/3',
          color: '#cd5b45',
          default: false,
          name: 'SOC 2',
          description: 'SOC 2 description',
        },
      },
    },
    project: {
      id: 'gid://gitlab/Project/2',
      nameWithNamespace: 'GitLab.org / GitLab Test',
      fullPath: '/gitlab/org/gitlab-test',
      webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
      __typename: 'Project',
    },
    auditEvent: {
      id: 'gid://gitlab/AuditEvents::ProjectAuditEvent/467',
      eventName: 'merge_request_merged',
      targetId: '2',
      details: '{}',
      ipAddress: '123.1.1.9',
      entityPath: 'gitlab-org/gitlab-test',
      entityId: '2',
      entityType: 'Project',
      author: {
        id: 'gid://gitlab/User/1',
        name: 'John Doe',
      },
      project: {
        id: 'gid://gitlab/Project/2',
        name: 'Test project',
        fullPath: 'gitlab-org/gitlab-test',
        webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
      },
      group: null,
      user: {
        id: 'gid://gitlab/User/1',
        name: 'John Doe',
      },
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
    violationData = mockComplianceViolationData,
  } = {}) => ({
    Query: {
      complianceViolation: () => {
        if (shouldThrowQueryError) {
          throw new Error('Query error');
        }

        return violationData;
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
        complianceCenterPath,
        ...props,
      },
    });
  };

  const findLoadingStatus = () =>
    wrapper.findByTestId('compliance-violation-details-loading-status');
  const findStatusDropdown = () => wrapper.findComponent(ComplianceViolationStatusDropdown);
  const findViolationDetails = () => wrapper.findByTestId('compliance-violation-details');
  const findAuditEvent = () => wrapper.findComponent(AuditEvent);
  const findViolationSection = () => wrapper.findComponent(ViolationSection);

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
      expect(title.text()).toBe(`Details of vio-${violationId}`);
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

    it('renders the violation section', () => {
      const violationSectionComponent = findViolationSection();
      expect(violationSectionComponent.exists()).toBe(true);
      expect(violationSectionComponent.props('control')).toEqual(
        mockComplianceViolationData.complianceControl,
      );
      expect(violationSectionComponent.props('complianceCenterPath')).toBe(complianceCenterPath);
    });

    describe('when violation has an audit event', () => {
      it('renders the audit event component with correct props', () => {
        const auditEventComponent = findAuditEvent();
        expect(auditEventComponent.exists()).toBe(true);
        expect(auditEventComponent.props('auditEvent')).toEqual(
          mockComplianceViolationData.auditEvent,
        );
      });
    });

    describe('when violation does not have an audit event', () => {
      it('renders the audit event component with correct props', () => {
        createComponent({
          resolverOptions: { violationData: { ...mockComplianceViolationData, auditEvent: null } },
        });
        const auditEventComponent = findAuditEvent();
        expect(auditEventComponent.exists()).toBe(false);
      });
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
