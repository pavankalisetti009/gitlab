import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ComplianceViolationDetailsApp from 'ee/compliance_violations/components/compliance_violation_details_app.vue';

describe('ComplianceViolationDetailsApp', () => {
  let wrapper;

  const mockComplianceViolation = {
    id: '123',
    status: 'In review',
    project: {
      nameWithNamespace: 'GitLab.org / GitLab',
      webUrl: 'https://gitlab.com/gitlab-org/gitlab',
    },
  };

  const createComponent = (options = {}) => {
    wrapper = shallowMountExtended(ComplianceViolationDetailsApp, {
      propsData: {
        violationId: '123',
        ...options.propsData,
      },
      mocks: {
        $apollo: {
          queries: {
            complianceViolation: {
              loading: false,
            },
          },
        },
        ...options.mocks,
      },
      data() {
        return {
          complianceViolation: mockComplianceViolation,
          ...options.data,
        };
      },
    });
  };

  const findLoadingStatus = () =>
    wrapper.findByTestId('compliance-violation-details-loading-status');
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
    beforeEach(() => {
      createComponent();
    });

    it('does not show loading icon', () => {
      expect(findLoadingStatus().exists()).toBe(false);
    });

    it('shows violation details', () => {
      expect(findViolationDetails().exists()).toBe(true);
    });

    it('displays the correct title', () => {
      const title = wrapper.findByTestId('compliance-violation-title');
      expect(title.text()).toBe(`Details of vio-${mockComplianceViolation.id}`);
    });

    it('displays the violation status', () => {
      const statusText = wrapper.findByTestId('compliance-violation-status').text();
      expect(statusText).toContain(`Status: ${mockComplianceViolation.status}`);
    });

    it('displays the project location with link', () => {
      const projectLink = wrapper.findByTestId('compliance-violation-location-link');
      expect(projectLink.exists()).toBe(true);
      expect(projectLink.text()).toBe(mockComplianceViolation.project.nameWithNamespace);
      expect(projectLink.attributes('href')).toBe(mockComplianceViolation.project.webUrl);
    });
  });
});
