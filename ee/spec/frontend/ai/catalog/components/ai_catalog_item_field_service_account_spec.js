import { shallowMount } from '@vue/test-utils';
import { GlAvatarLabeled, GlAvatarLink, GlLink, GlSprintf } from '@gitlab/ui';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import AiCatalogItemFieldServiceAccount from 'ee/ai/catalog/components/ai_catalog_item_field_service_account.vue';
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

  const findServiceAccountAvatar = () => wrapper.findComponent(GlAvatarLabeled);
  const findServiceAccountLink = () => wrapper.findComponent(GlAvatarLink);
  const findServiceAccountField = () => wrapper.findComponent(AiCatalogItemField);

  beforeEach(() => {
    createComponent();
  });

  it('renders help text with full phrase', () => {
    const helpText = findServiceAccountField().text();
    expect(helpText).toBe(
      'Service accounts represent non-human entities. This is the account that you mention or assign to trigger the flow.',
    );
  });

  it('renders service account docs link in help text', () => {
    const link = findServiceAccountField().findComponent(GlLink);
    expect(link.attributes('href')).toBe('/help/user/profile/service_accounts');
  });

  it('renders service account avatar', () => {
    expect(findServiceAccountAvatar().props()).toMatchObject({
      size: 32,
      src: mockServiceAccount.avatarUrl,
      label: mockServiceAccount.name,
      subLabel: `@${mockServiceAccount.username}`,
    });
  });

  it('renders service account link', () => {
    expect(findServiceAccountLink().attributes()).toMatchObject({
      href: mockServiceAccount.webPath,
      title: mockServiceAccount.name,
    });
  });
});
