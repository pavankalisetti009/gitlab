import { GlTable, GlDisclosureDropdown, GlLink } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import SelfHostedModelsTable from 'ee/pages/admin/ai/self_hosted_models/components/self_hosted_models_table.vue';
import DeleteSelfHostedModelDisclosureItem from 'ee/pages/admin/ai/self_hosted_models/components/delete_self_hosted_model_disclosure_item.vue';
import { mockSelfHostedModelsList } from './mock_data';

describe('SelfHostedModelsTable', () => {
  let wrapper;

  const basePath = '/admin/ai/self_hosted_models';
  const aiFeatureSettingsPath = '/admin/ai/feature_settings';
  const newSelfHostedModelPath = 'admin/ai/self_hosted_models/new';

  const createComponent = ({ props }) => {
    wrapper = extendedWrapper(
      mount(SelfHostedModelsTable, {
        propsData: {
          ...props,
        },
        provide: {
          basePath,
          aiFeatureSettingsPath,
          newSelfHostedModelPath,
        },
      }),
    );
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableHeaders = () => findTable().findAllComponents('th');
  const findTableRows = () => findTable().findAllComponents('tbody > tr');
  const findNthTableRow = (idx) => findTableRows().at(idx);
  const findDisclosureDropdowns = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findEditButtons = () => wrapper.findAllByTestId('model-edit-button');
  const findEmptyStateLink = () => wrapper.findComponent(GlLink);
  const findDeleteDisclosureItems = () =>
    wrapper.findAllComponents(DeleteSelfHostedModelDisclosureItem);

  it('renders the table component', () => {
    createComponent({ props: { models: mockSelfHostedModelsList } });

    expect(findTable().exists()).toBe(true);
  });

  it('renders table headers <th>', () => {
    createComponent({ props: { models: mockSelfHostedModelsList } });

    const expectedTableHeaderNames = [
      'Name',
      'Model',
      'Endpoint',
      'Model identifier',
      'API token',
      '', // The 'edit' column does not have a header name
    ];

    expect(findTableHeaders().wrappers.map((h) => h.text())).toEqual(expectedTableHeaderNames);
  });

  it('renders self-hosted model entries', () => {
    createComponent({ props: { models: mockSelfHostedModelsList } });

    expect(findTableRows().length).toEqual(2);

    const firstModel = findNthTableRow(0);

    expect(firstModel.text()).toContain('mock-self-hosted-model-1');
    expect(firstModel.text()).toContain('codellama');
    expect(firstModel.text()).toContain('https://mock-endpoint-1.com');
    expect(firstModel.find('[data-testid="check-circle-icon"]').exists()).toBe(true);
    expect(firstModel.text()).toContain('provider/some-model-1');
  });

  it('renders a disclosure dropdown for each self-hosted model entry', () => {
    createComponent({ props: { models: mockSelfHostedModelsList } });

    expect(findDisclosureDropdowns().length).toBe(2);
  });

  describe('when there are no self-hosted models', () => {
    it('renders empty state text', () => {
      createComponent({ props: { models: [] } });

      expect(findTable().text()).toMatch(
        'You do not currently have any self-hosted models. Add a self-hosted model to get started.',
      );
    });

    it('renders a link to create a new self-hosted model', () => {
      createComponent({ props: { models: [] } });

      expect(findEmptyStateLink().attributes('href')).toBe(newSelfHostedModelPath);
    });
  });

  describe('Editing a model', () => {
    it('renders an edit button for each model', () => {
      createComponent({ props: { models: mockSelfHostedModelsList } });

      expect(findEditButtons().length).toBe(2);

      findEditButtons().wrappers.forEach((button) => {
        expect(button.text()).toEqual('Edit');
      });
    });

    it('routes to the correct path', () => {
      createComponent({ props: { models: mockSelfHostedModelsList } });

      findEditButtons().wrappers.forEach((button, idx) => {
        expect(button.html()).toContain(`href="/admin/ai/self_hosted_models/${idx + 1}/edit"`);
      });
    });
  });

  describe('Deleting a model', () => {
    it('renders a delete button for each model', () => {
      createComponent({ props: { models: mockSelfHostedModelsList } });

      expect(findDeleteDisclosureItems().length).toBe(2);

      findDeleteDisclosureItems().wrappers.forEach((button) => {
        expect(button.text()).toEqual('Delete');
      });
    });
  });
});
