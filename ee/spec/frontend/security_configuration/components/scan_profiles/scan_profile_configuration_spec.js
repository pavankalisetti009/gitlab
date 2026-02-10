import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTableLite, GlButton, GlAlert, GlLink, GlLoadingIcon } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import ScanProfileConfiguration from 'ee/security_configuration/components/scan_profiles/scan_profile_configuration.vue';
import ScanProfileTable from '~/security_configuration/components/scan_profiles/scan_profile_table.vue';
import DisableScanProfileConfirmationModal from 'ee/security_configuration/components/scan_profiles/disable_scan_profile_confirmation_modal.vue';
import ScanProfileDetailsModal from 'ee/security_configuration/components/scan_profiles/scan_profile_details_modal.vue';
import InsufficientPermissionsPopover from 'ee/security_configuration/components/scan_profiles/insufficient_permissions_popover.vue';
import ScanProfileLaunchModal from 'ee/security_configuration/components/scan_profiles/scan_profile_launch_modal.vue';
import availableProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/group_available_security_scan_profiles.query.graphql';
import projectProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/project_security_scan_profiles.query.graphql';
import attachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_attach.mutation.graphql';
import detachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_detach.mutation.graphql';
import profileDetailsQuery from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile.query.graphql';
import { SCAN_PROFILE_TYPE_SECRET_DETECTION } from '~/security_configuration/constants';

Vue.use(VueApollo);

describe('ScanProfileConfiguration', () => {
  let wrapper;
  let mockToastShow;

  const mockProfile = {
    id: 'gid://gitlab/Security::ScanProfile/2',
    name: 'Secret Push Protection (default)',
    description:
      "GitLab's recommended baseline protection using industry-standard detection rules. Blocks common secrets like API keys, tokens, and passwords from being committed to your repository, with detection optimized to minimize false positives",
    gitlabRecommended: true,
    scanType: 'SECRET_DETECTION',
    __typename: 'ScanProfileType',
  };

  const mockProjectId = 'gid://gitlab/Project/1';

  const createAvailableProfilesResolver = (profiles = [mockProfile]) =>
    jest.fn().mockResolvedValue({
      data: {
        group: {
          id: 'gid://gitlab/Group/1',
          name: 'group',
          availableSecurityScanProfiles: profiles,
          __typename: 'Group',
        },
      },
    });

  const createProjectProfilesResolver = (profiles = []) =>
    jest.fn().mockResolvedValue({
      data: {
        project: {
          id: mockProjectId,
          name: 'project',
          securityScanProfiles: profiles,
          __typename: 'Project',
        },
      },
    });

  const createAttachMutationResolver = (errors = []) =>
    jest.fn().mockResolvedValue({
      data: {
        securityScanProfileAttach: {
          errors,
        },
      },
    });

  const createDetachMutationResolver = (errors = []) =>
    jest.fn().mockResolvedValue({
      data: {
        securityScanProfileDetach: {
          errors,
        },
      },
    });

  const createProfileDetailsResolver = (profile = mockProfile) =>
    jest.fn().mockResolvedValue({
      data: {
        securityScanProfile: profile,
      },
    });

  const createComponent = ({
    availableProfilesResolver = createAvailableProfilesResolver(),
    projectProfilesResolver = createProjectProfilesResolver(),
    attachResolver = createAttachMutationResolver(),
    detachResolver = createDetachMutationResolver(),
    profileDetailsResolver = createProfileDetailsResolver(),
    canApplyProfiles = true,
    securityScanProfilesLicensed = true,
  } = {}) => {
    mockToastShow = jest.fn();

    const apolloProvider = createMockApollo([
      [availableProfilesQuery, availableProfilesResolver],
      [projectProfilesQuery, projectProfilesResolver],
      [attachMutation, attachResolver],
      [detachMutation, detachResolver],
      [profileDetailsQuery, profileDetailsResolver],
    ]);

    wrapper = mountExtended(ScanProfileConfiguration, {
      apolloProvider,
      provide: {
        projectFullPath: 'group/project',
        groupFullPath: 'group',
        canApplyProfiles,
        securityScanProfilesLicensed,
      },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
      stubs: {
        ScanProfileLaunchModal: stubComponent(ScanProfileLaunchModal),
      },
    });

    return wrapper;
  };

  const findTable = () => wrapper.findComponent(ScanProfileTable);
  const findGlTable = () => wrapper.findComponent(GlTableLite);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLink = () => wrapper.findComponent(GlLink);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findDisableModal = () => wrapper.findComponent(DisableScanProfileConfirmationModal);
  const findDetailsModal = () => wrapper.findComponent(ScanProfileDetailsModal);
  const findPopover = () => wrapper.findComponent(InsufficientPermissionsPopover);

  describe('loading state', () => {
    it('shows loading icon while queries are loading', () => {
      const loadingResolver = jest.fn(() => new Promise(() => {}));
      createComponent({
        availableProfilesResolver: loadingResolver,
        projectProfilesResolver: loadingResolver,
      });

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findTable().exists()).toBe(false);
    });
  });

  describe('error handling', () => {
    it('displays error message when available profiles query fails', async () => {
      const errorResolver = jest.fn().mockRejectedValue(new Error('Query failed'));
      createComponent({ availableProfilesResolver: errorResolver });
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('Error loading profiles');
    });

    it('displays error message when project profiles query fails', async () => {
      const errorResolver = jest.fn().mockRejectedValue(new Error('Query failed'));
      createComponent({ projectProfilesResolver: errorResolver });
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('Error loading profiles');
    });
  });

  describe('table rendering', () => {
    it('renders table with correct fields', async () => {
      createComponent();
      await waitForPromises();

      const table = findGlTable();
      expect(table.exists()).toBe(true);
      expect(table.props('fields')).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ key: 'scanType', label: 'Scanner' }),
          expect.objectContaining({ key: 'name', label: 'Profile' }),
          expect.objectContaining({ key: 'status', label: 'Status' }),
          expect.objectContaining({ key: 'actions', label: '' }),
        ]),
      );
    });

    it('renders "No profile applied" when profile is not configured', async () => {
      createComponent();
      await waitForPromises();

      expect(findAlert().exists()).toBe(false);
      expect(findTable().exists()).toBe(true);

      expect(wrapper.text()).toContain('No profile applied');
    });

    it('renders profile name as link when profile is configured', async () => {
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockProfile]),
      });
      await waitForPromises();

      const links = wrapper.findAllComponents(GlLink);
      const profileLinks = links.filter((link) => link.text() === mockProfile.name);
      expect(profileLinks.length).toBeGreaterThan(0);
    });

    it('shows not configured status when profile is not attached', async () => {
      createComponent();
      await waitForPromises();

      expect(wrapper.text()).toContain('Not configured');
      expect(wrapper.text()).toContain('Apply profile to enable');
    });

    it('shows active status when profile is attached', async () => {
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockProfile]),
      });
      await waitForPromises();

      expect(wrapper.text()).toContain('Active');
    });
  });

  describe('when unlicensed', () => {
    beforeEach(() => {
      createComponent({ securityScanProfilesLicensed: false });
    });

    it('renders table with correct fields', () => {
      const table = findGlTable();
      expect(table.exists()).toBe(true);
      expect(table.props('fields')).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ key: 'scanType', label: 'Scanner' }),
          expect.objectContaining({ key: 'name', label: 'Profile' }),
          expect.objectContaining({ key: 'status', label: 'Status' }),
          expect.objectContaining({ key: 'actions', label: '' }),
        ]),
      );
    });

    it('renders "No profile applied"', () => {
      expect(findAlert().exists()).toBe(false);
      expect(findTable().exists()).toBe(true);

      expect(wrapper.text()).toContain('No profile applied');
    });

    it('shows "Available with Ultimate" with a learn more link', () => {
      expect(wrapper.text()).toContain('Available with Ultimate');
      expect(findLink().text()).toBe('Learn more about the Ultimate security suite');
      expect(findLink().props('href')).toBe(`${PROMO_URL}/solutions/application-security-testing/`);
    });

    it('renders disabled apply and preview buttons', () => {
      const buttons = wrapper.findAllComponents(GlButton);
      const applyButton = buttons.wrappers.find((btn) =>
        btn.text().includes('Apply default profile'),
      );
      const previewButton = buttons.wrappers.find((btn) => btn.props('icon') === 'eye');

      expect(applyButton.props('disabled')).toBe(true);
      expect(previewButton.props('disabled')).toBe(true);
    });
  });

  describe('apply profile', () => {
    it('calls attach mutation when apply button is clicked', async () => {
      const attachResolver = createAttachMutationResolver();
      createComponent({ attachResolver });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const applyButton = buttons.wrappers.find((btn) =>
        btn.text().includes('Apply default profile'),
      );

      expect(applyButton).toBeDefined();
      await applyButton.trigger('click');
      await waitForPromises();

      expect(attachResolver).toHaveBeenCalledWith({
        input: {
          securityScanProfileId: mockProfile.id,
          projectIds: [mockProjectId],
        },
      });
    });

    it('applies profile by calling the mutation', async () => {
      const attachResolver = createAttachMutationResolver();
      createComponent({ attachResolver });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const applyButton = buttons.wrappers.find((btn) =>
        btn.text().includes('Apply default profile'),
      );

      expect(applyButton).toBeDefined();
      expect(applyButton.props('loading')).toBe(false);
      await applyButton.trigger('click');
      await waitForPromises();

      expect(attachResolver).toHaveBeenCalled();
    });

    it('handles mutation errors', async () => {
      const attachResolver = createAttachMutationResolver(['Error message']);
      createComponent({ attachResolver });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const applyButton = buttons.wrappers.find((btn) =>
        btn.text().includes('Apply default profile'),
      );

      await applyButton.trigger('click');
      await waitForPromises();

      expect(attachResolver).toHaveBeenCalled();
    });

    it('shows error message when attach mutation throws error', async () => {
      const attachResolver = jest.fn().mockRejectedValue(new Error('Network error'));
      createComponent({ attachResolver });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const applyButton = buttons.wrappers.find((btn) =>
        btn.text().includes('Apply default profile'),
      );

      expect(applyButton).toBeDefined();
      await applyButton.trigger('click');
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('Error applying profile');
    });
  });

  describe('detach profile', () => {
    it('opens disable modal when disable button is clicked', async () => {
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockProfile]),
      });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const disableButton = buttons.wrappers.find((btn) => btn.text().includes('Disable'));

      expect(disableButton).toBeDefined();
      await disableButton.trigger('click');

      expect(findDisableModal().props('visible')).toBe(true);
      expect(findDisableModal().props('scannerName')).toBe('Secret Detection');
    });

    it('calls detach mutation when confirmed in modal', async () => {
      const detachResolver = createDetachMutationResolver();
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockProfile]),
        detachResolver,
      });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const disableButton = buttons.wrappers.find((btn) => btn.text().includes('Disable'));

      expect(disableButton).toBeDefined();
      await disableButton.trigger('click');
      await waitForPromises();

      findDisableModal().vm.$emit('confirm');
      await waitForPromises();

      expect(detachResolver).toHaveBeenCalledWith({
        input: {
          securityScanProfileId: mockProfile.id,
          projectIds: [mockProjectId],
        },
      });
    });

    it('detaches profile by calling the mutation', async () => {
      const detachResolver = createDetachMutationResolver();
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockProfile]),
        detachResolver,
      });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const disableButton = buttons.wrappers.find((btn) => btn.text().includes('Disable'));

      expect(disableButton).toBeDefined();
      expect(disableButton.props('loading')).toBe(false);
      await disableButton.trigger('click');
      await waitForPromises();

      findDisableModal().vm.$emit('confirm');
      await waitForPromises();

      expect(detachResolver).toHaveBeenCalled();
    });

    it('closes modal when cancel is clicked', async () => {
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockProfile]),
      });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const disableButton = buttons.wrappers.find((btn) => btn.text().includes('Disable'));

      expect(disableButton).toBeDefined();
      await disableButton.trigger('click');
      await waitForPromises();

      findDisableModal().vm.$emit('cancel');
      await nextTick();

      expect(findDisableModal().props('visible')).toBe(false);
    });
  });

  describe('preview profile', () => {
    it('opens details modal when preview button is clicked', async () => {
      createComponent();
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const previewButton = buttons.wrappers.find((btn) => btn.props('icon') === 'eye');

      expect(previewButton).toBeDefined();
      await previewButton.trigger('click');

      expect(findDetailsModal().props('visible')).toBe(true);
      expect(findDetailsModal().props('profileId')).toBe(mockProfile.id);
    });

    it('opens details modal when profile name link is clicked', async () => {
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockProfile]),
      });
      await waitForPromises();

      const links = wrapper.findAllComponents(GlLink);
      const profileLinks = links.filter((link) => link.text() === mockProfile.name);
      expect(profileLinks.length).toBeGreaterThan(0);
      await profileLinks.at(0).trigger('click');

      expect(findDetailsModal().props('visible')).toBe(true);
      expect(findDetailsModal().props('profileId')).toBe(mockProfile.id);
    });

    it('closes details modal when close event is emitted', async () => {
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockProfile]),
      });
      await waitForPromises();

      const links = wrapper.findAllComponents(GlLink);
      const profileLinks = links.filter((link) => link.text() === mockProfile.name);
      expect(profileLinks.length).toBeGreaterThan(0);
      await profileLinks.at(0).trigger('click');

      findDetailsModal().vm.$emit('close');
      await nextTick();

      expect(findDetailsModal().props('visible')).toBe(false);
    });

    it('applies profile from details modal', async () => {
      const attachResolver = createAttachMutationResolver();
      createComponent({
        attachResolver,
        projectProfilesResolver: createProjectProfilesResolver([mockProfile]),
      });
      await waitForPromises();

      const links = wrapper.findAllComponents(GlLink);
      const profileLinks = links.filter((link) => link.text() === mockProfile.name);
      expect(profileLinks.length).toBeGreaterThan(0);
      await profileLinks.at(0).trigger('click');
      await waitForPromises();

      findDetailsModal().vm.$emit('apply', mockProfile.id);
      await waitForPromises();

      expect(attachResolver).toHaveBeenCalled();
    });
  });

  describe('permissions', () => {
    it('shows lock icon and popover on apply button when user cannot apply profiles', async () => {
      createComponent({ canApplyProfiles: false });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const applyButton = buttons.wrappers.find((btn) =>
        btn.text().includes('Apply default profile'),
      );

      expect(applyButton.text()).toContain('Apply default profile');
      expect(applyButton.html()).toContain('lock');
      expect(findPopover().exists()).toBe(true);
      expect(findPopover().props('target')).toContain('apply-button');
    });

    it('shows lock icon and popover on disable button when user cannot apply profiles', async () => {
      createComponent({
        canApplyProfiles: false,
        projectProfilesResolver: createProjectProfilesResolver([mockProfile]),
      });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const disableButton = buttons.wrappers.find((btn) => btn.text().includes('Disable'));

      expect(disableButton.html()).toContain('lock');

      const popovers = wrapper.findAllComponents(InsufficientPermissionsPopover);
      expect(popovers.length).toBeGreaterThan(0);
      const disablePopover = popovers.wrappers.find((p) =>
        p.props('target').includes('disable-button'),
      );
      expect(disablePopover).toBeDefined();
    });

    it('allows preview button to be clicked when user cannot apply profiles', async () => {
      createComponent({ canApplyProfiles: false });
      await waitForPromises();

      const buttons = wrapper.findAllComponents(GlButton);
      const previewButton = buttons.wrappers.find((btn) => btn.props('icon') === 'eye');

      expect(previewButton.props('disabled')).toBe(false);
    });
  });

  describe('apollo queries', () => {
    it('calls available profiles query with correct variables', () => {
      const resolver = createAvailableProfilesResolver();
      createComponent({ availableProfilesResolver: resolver });

      expect(resolver).toHaveBeenCalledWith({
        fullPath: 'group',
        type: SCAN_PROFILE_TYPE_SECRET_DETECTION,
      });
    });

    it('calls project profiles query with correct variables', () => {
      const resolver = createProjectProfilesResolver();
      createComponent({ projectProfilesResolver: resolver });

      expect(resolver).toHaveBeenCalledWith({
        fullPath: 'group/project',
      });
    });
  });
});
