import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  SCAN_PROFILE_STATUS_APPLIED,
  SCAN_PROFILE_STATUS_DISABLED,
} from '~/security_configuration/constants';
import BulkScannerProfileConfiguration from 'ee/security_inventory/components/bulk_scanner_profile_configuration.vue';
import AvailableSecurityScanProfiles from 'ee/security_inventory/graphql/available_security_scan_profiles.query.graphql';

Vue.use(VueApollo);

describe('BulkScannerProfileConfiguration', () => {
  let wrapper;
  let mockApollo;

  const mockQueryResponse = () => {
    return {
      data: {
        group: {
          id: 'gid://gitlab/Group/1',
          availableSecurityScanProfiles: [
            {
              id: 'gid://gitlab/Security::ScanProfile/1',
              name: 'Secret Detection (default)',
              description: 'Default Secret Detection configuration',
              scanType: 'SECRET_DETECTION',
              gitlabRecommended: true,
            },
          ],
        },
      },
    };
  };

  const handler = jest.fn().mockResolvedValue(mockQueryResponse());

  const createComponent = ({
    availableSecurityScanProfilesHandler = handler,
    statusPatches = {},
  } = {}) => {
    mockApollo = createMockApollo([
      [AvailableSecurityScanProfiles, availableSecurityScanProfilesHandler],
    ]);

    wrapper = mountExtended(BulkScannerProfileConfiguration, {
      apolloProvider: mockApollo,
      propsData: {
        statusPatches,
      },
      provide: {
        groupFullPath: 'test-group',
      },
    });
  };

  const findScanTypeCell = () => wrapper.findByTestId('scan-type-cell');
  const findProfileNameCell = () => wrapper.findByTestId('profile-name-cell');
  const findApplyDefaultProfileButton = () => wrapper.findByTestId('apply-default-profile-button');
  const findPreviewDefaultProfileButton = () =>
    wrapper.findByTestId('preview-default-profile-button');
  const findDisableForAllButton = () => wrapper.findByTestId('disable-for-all-button');

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  it('queries available security scan profiles', () => {
    expect(handler).toHaveBeenCalledWith({
      fullPath: 'test-group',
      gitlabRecommended: true,
    });
  });

  describe('default state', () => {
    it('renders scanner type label and name', () => {
      expect(findScanTypeCell().text()).toContain('SD');
      expect(findScanTypeCell().text()).toContain('Secret detection');
    });

    it('applies status classes to icon', () => {
      const classes = wrapper.findByTestId('scan-type-icon').classes();

      expect(classes).toContain('gl-bg-feedback-neutral');
      expect(classes).toContain('gl-border-feedback-neutral');
    });

    it('renders relevant buttons', () => {
      expect(findApplyDefaultProfileButton().exists()).toBe(true);
      expect(findPreviewDefaultProfileButton().exists()).toBe(true);
      expect(findDisableForAllButton().exists()).toBe(true);
    });
  });

  describe('with applied status patch', () => {
    beforeEach(async () => {
      createComponent({
        statusPatches: {
          'gid://gitlab/Security::ScanProfile/1': {
            status: SCAN_PROFILE_STATUS_APPLIED,
          },
        },
      });
      await waitForPromises();
    });

    it('applies status classes to icon', () => {
      const classes = wrapper.findByTestId('scan-type-icon').classes();

      expect(classes).toContain('gl-bg-feedback-success');
      expect(classes).toContain('gl-border-feedback-success');
    });

    it('renders profile name as link', () => {
      expect(findProfileNameCell().text()).toContain('Secret Detection (default)');
    });

    it('renders "Disable for all" button', () => {
      expect(findDisableForAllButton().exists()).toBe(true);
    });
  });

  describe('with disabled status patch', () => {
    beforeEach(async () => {
      createComponent({
        statusPatches: {
          'gid://gitlab/Security::ScanProfile/1': {
            status: SCAN_PROFILE_STATUS_DISABLED,
          },
        },
      });
      await waitForPromises();
    });

    it('applies status classes to icon', () => {
      const classes = wrapper.findByTestId('scan-type-icon').classes();

      expect(classes).toContain('gl-bg-feedback-danger');
      expect(classes).toContain('gl-border-feedback-danger');
    });

    it('renders "No profile applied" text', () => {
      expect(findProfileNameCell().text()).toContain('No profile applied');
    });

    it('renders relevant buttons', () => {
      expect(findApplyDefaultProfileButton().exists()).toBe(true);
      expect(findPreviewDefaultProfileButton().exists()).toBe(true);
    });
  });
});
