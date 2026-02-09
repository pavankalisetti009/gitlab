import { shallowMount } from '@vue/test-utils';
import { GlLink, GlSprintf, GlButton } from '@gitlab/ui';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import AiCatalogItemFieldServiceAccount from 'ee/ai/catalog/components/ai_catalog_item_field_service_account.vue';
import ServiceAccountAvatar from 'ee/ai/catalog/components/service_account_avatar.vue';
import ServiceAccountProjectMemberships from 'ee/ai/catalog/components/service_account_project_memberships.vue';
import { mockServiceAccount } from '../mock_data';

describe('AiCatalogItemFieldServiceAccount', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AiCatalogItemFieldServiceAccount, {
      propsData: {
        serviceAccount: mockServiceAccount,
        itemType: 'FLOW',
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findServiceAccountField = () => wrapper.findComponent(AiCatalogItemField);
  const findServiceAccountAvatar = () => wrapper.findComponent(ServiceAccountAvatar);
  const findViewPermissionsButton = () => wrapper.findComponent(GlButton);
  const findServiceAccountProjectMemberships = () =>
    wrapper.findComponent(ServiceAccountProjectMemberships);

  beforeEach(() => {
    createComponent();
  });

  it('renders help text with full phrase', () => {
    const helpText = findServiceAccountField().text();
    expect(helpText).toContain(
      'Service accounts represent non-human entities. This is the account that you mention or assign to trigger the flow.',
    );
  });

  it('renders service account docs link in help text', () => {
    const link = findServiceAccountField().findComponent(GlLink);
    expect(link.attributes('href')).toBe('/help/user/profile/service_accounts');
  });

  it('renders service account avatar component', () => {
    expect(findServiceAccountAvatar().props('serviceAccount')).toEqual(mockServiceAccount);
  });

  it('renders button to view projects and permissions', () => {
    expect(findViewPermissionsButton().text()).toBe(
      'View projects and permissions of this service account',
    );
  });

  it('opens drawer when button is clicked', async () => {
    expect(findServiceAccountProjectMemberships().props('isOpen')).toBe(false);

    await findViewPermissionsButton().vm.$emit('click');

    expect(findServiceAccountProjectMemberships().props('isOpen')).toBe(true);
  });

  it('closes drawer when close event is emitted', async () => {
    await findViewPermissionsButton().vm.$emit('click');
    expect(findServiceAccountProjectMemberships().props('isOpen')).toBe(true);

    await findServiceAccountProjectMemberships().vm.$emit('close');

    expect(findServiceAccountProjectMemberships().props('isOpen')).toBe(false);
  });
});
