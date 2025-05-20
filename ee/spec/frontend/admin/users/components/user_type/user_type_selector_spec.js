import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AdminRoleDropdown from 'ee/admin/users/components/user_type/admin_role_dropdown.vue';
import UserTypeSelector, {
  USER_TYPE_AUDITOR,
} from 'ee/admin/users/components/user_type/user_type_selector.vue';
import UserTypeSelectorCe, {
  USER_TYPE_REGULAR,
  USER_TYPE_ADMIN,
} from '~/admin/users/components/user_type/user_type_selector.vue';
import RegularAccessSummary from '~/admin/users/components/user_type/regular_access_summary.vue';
import AuditorAccessSummary from 'ee/admin/users/components/user_type/auditor_access_summary.vue';
import AdminAccessSummary from '~/admin/users/components/user_type/admin_access_summary.vue';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';

describe('UserTypeSelector component', () => {
  let wrapper;

  const createWrapper = ({
    userType = 'regular',
    licenseAllowsAuditorUser = true,
    adminRoleId = 1,
    customRoles = true,
    customAdminRoles = true,
  } = {}) => {
    wrapper = shallowMountExtended(UserTypeSelector, {
      propsData: { userType, licenseAllowsAuditorUser, adminRoleId, isCurrentUser: true },
      provide: { glFeatures: { customRoles, customAdminRoles } },
      stubs: {
        UserTypeSelectorCe: stubComponent(UserTypeSelectorCe, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });

    return waitForPromises();
  };

  const findUserTypeSelectorCE = () => wrapper.findComponent(UserTypeSelectorCe);
  const findRegularAccessSummary = () => wrapper.findComponent(RegularAccessSummary);
  const findAuditorAccessSummary = () => wrapper.findComponent(AuditorAccessSummary);
  const findAdminAccessSummary = () => wrapper.findComponent(AdminAccessSummary);
  const findDescription = () => wrapper.findByTestId('slot-description');

  it('renders CE UserTypeSelector', () => {
    createWrapper();

    expect(findUserTypeSelectorCE().props()).toMatchObject({
      userType: 'regular',
      isCurrentUser: true,
    });
  });

  describe.each`
    licenseAllowsAuditorUser | userTypes
    ${true}                  | ${[USER_TYPE_REGULAR, USER_TYPE_AUDITOR, USER_TYPE_ADMIN]}
    ${false}                 | ${[USER_TYPE_REGULAR, USER_TYPE_ADMIN]}
  `(
    'when licenseAllowsAuditorUser prop is $licenseAllowsAuditorUser',
    ({ licenseAllowsAuditorUser, userTypes }) => {
      it('passes expected userTypes prop to CE UserTypeSelector', () => {
        createWrapper({ licenseAllowsAuditorUser });

        expect(findUserTypeSelectorCE().props('userTypes')).toEqual(userTypes);
      });
    },
  );

  describe.each`
    userType     | regular  | auditor  | admin
    ${'regular'} | ${true}  | ${false} | ${false}
    ${'auditor'} | ${false} | ${true}  | ${false}
    ${'admin'}   | ${false} | ${false} | ${true}
  `('when $userType is selected', ({ userType, regular, auditor, admin }) => {
    beforeEach(() => {
      createWrapper();
      findUserTypeSelectorCE().vm.$emit('access-change', userType);
    });

    it('shows/hides regular access summary', () => {
      expect(findRegularAccessSummary().exists()).toBe(regular);
    });

    it('shows/hides auditor access summary', () => {
      expect(findAuditorAccessSummary().exists()).toBe(auditor);
    });

    it('shows/hides admin access summary', () => {
      expect(findAdminAccessSummary().exists()).toBe(admin);
    });
  });

  describe('when admin role dropdown is shown', () => {
    beforeEach(() => createWrapper());

    describe.each`
      userType     | findAccessSummary
      ${'regular'} | ${findRegularAccessSummary}
      ${'auditor'} | ${findAuditorAccessSummary}
    `('when $userType is selected', ({ userType, findAccessSummary }) => {
      beforeEach(() => createWrapper({ userType }));

      it('shows description', () => {
        expect(findDescription().text()).toBe(
          'Review and set Admin area access with a custom admin role.',
        );
      });

      it('shows admin role dropdown in access summary', () => {
        expect(findAccessSummary().findComponent(AdminRoleDropdown).props('roleId')).toBe(1);
      });
    });
  });

  describe.each`
    options                                             | findAccessSummary
    ${{ customRoles: false, userType: 'regular' }}      | ${findRegularAccessSummary}
    ${{ customRoles: false, userType: 'auditor' }}      | ${findAuditorAccessSummary}
    ${{ customAdminRoles: false, userType: 'regular' }} | ${findRegularAccessSummary}
    ${{ customAdminRoles: false, userType: 'auditor' }} | ${findAuditorAccessSummary}
    ${{ userType: 'admin' }}                            | ${findAdminAccessSummary}
  `(
    'when admin role dropdown is not shown because of $options',
    ({ options, findAccessSummary }) => {
      beforeEach(() => createWrapper(options));

      it('does not show description', () => {
        expect(findDescription().exists()).toBe(false);
      });

      it('does not show admin role dropdown in access summary', () => {
        expect(findAccessSummary().findComponent(AdminRoleDropdown).exists()).toBe(false);
      });
    },
  );
});
