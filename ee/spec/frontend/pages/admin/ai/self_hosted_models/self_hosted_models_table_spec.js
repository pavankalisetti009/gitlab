import { GlTable, GlDisclosureDropdown, GlLink, GlTruncate, GlSearchBoxByType } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SelfHostedModelsTable from 'ee/pages/admin/ai/self_hosted_models/components/self_hosted_models_table.vue';
import DeleteSelfHostedModelDisclosureItem from 'ee/pages/admin/ai/self_hosted_models/components/delete_self_hosted_model_disclosure_item.vue';
import { mockSelfHostedModelsList } from './mock_data';

describe('SelfHostedModelsTable', () => {
  let wrapper;

  const basePath = '/admin/ai/self_hosted_models';
  const newSelfHostedModelPath = 'admin/ai/self_hosted_models/new';

  const createComponent = ({ props }) => {
    wrapper = mountExtended(SelfHostedModelsTable, {
      propsData: {
        ...props,
      },
      provide: {
        basePath,
        newSelfHostedModelPath,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableHeaders = () => findTable().findAllComponents('th');
  const findTableRows = () => findTable().findAllComponents('tbody > tr');
  const findNthTableRow = (idx) => findTableRows().at(idx);
  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByType);
  const findDisclosureDropdowns = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findEditButtons = () => wrapper.findAllByTestId('model-edit-button');
  const findEmptyStateLink = () => wrapper.findComponent(GlLink);
  const findTruncators = () => wrapper.findAllComponents(GlTruncate);
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

    const firstModelTextContent = firstModel
      .findAll('td')
      .wrappers.map((cell) => cell.text().replace(/\u200E/g, '')); // Remove U+200E left-to-right marks added by the GlTruncate component

    expect(firstModelTextContent).toContain('mock-self-hosted-model-1');
    expect(firstModelTextContent).toContain('codellama');
    expect(firstModelTextContent).toContain('https://mock-endpoint-1.com');
    expect(firstModelTextContent).toContain('provider/some-model-1');
    expect(firstModel.find('[data-testid="check-circle-icon"]').exists()).toBe(true);
  });

  it('truncates name and endpoint', () => {
    const model = mockSelfHostedModelsList[0];

    createComponent({ props: { models: [model] } });

    const nameTruncator = findTruncators().at(0);
    const endpointTruncator = findTruncators().at(1);

    expect(nameTruncator.props('text')).toBe(model.name);
    expect(endpointTruncator.props('text')).toBe(model.endpoint);
  });

  it('renders a disclosure dropdown for each self-hosted model entry', () => {
    createComponent({ props: { models: mockSelfHostedModelsList } });

    expect(findDisclosureDropdowns().length).toBe(2);
  });

  describe('search', () => {
    beforeEach(() => {
      createComponent({ props: { models: mockSelfHostedModelsList } });
    });

    it('renders a search bar', () => {
      expect(findSearchBox().exists()).toBe(true);
    });

    it('can search the table', async () => {
      await findSearchBox().vm.$emit('input', 'mock-self-hosted-model-1');

      expect(findTableRows().length).toEqual(1);
      expect(findTableRows().at(0).text()).toContain('mock-self-hosted-model-1');
    });
  });

  describe('when there are no self-hosted models', () => {
    beforeEach(() => {
      createComponent({ props: { models: [] } });
    });

    it('renders empty state text', () => {
      expect(findTable().text()).toMatch(
        'You do not currently have any self-hosted models. Add a self-hosted model to get started.',
      );
    });

    it('renders a link to create a new self-hosted model', () => {
      expect(findEmptyStateLink().attributes('href')).toBe(newSelfHostedModelPath);
    });
  });

  describe('Editing a model', () => {
    beforeEach(() => {
      createComponent({ props: { models: mockSelfHostedModelsList } });
    });

    it('renders an edit button for each model', () => {
      expect(findEditButtons().length).toBe(2);

      findEditButtons().wrappers.forEach((button) => {
        expect(button.text()).toEqual('Edit');
      });
    });

    it('routes to the correct path', () => {
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
