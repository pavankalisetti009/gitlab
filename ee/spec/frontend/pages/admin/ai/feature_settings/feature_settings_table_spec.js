import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsTable from 'ee/pages/admin/ai/feature_settings/components/feature_settings_table.vue';
import { mockAiFeatureSettings } from './mock_data';

describe('FeatureSettingsTable', () => {
  let wrapper;

  const createComponent = ({ props } = {}) => {
    const newSelfHostedModelPath = '/admin/self_hosted_models/new';

    wrapper = mountExtended(FeatureSettingsTable, {
      propsData: {
        aiFeatureSettings: mockAiFeatureSettings,
        ...props,
      },
      provide: {
        newSelfHostedModelPath,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableHeaders = () => findTable().findAllComponents('th');
  const findTableRows = () => findTable().findAllComponents('tbody > tr');
  const findLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  it('renders the table component', () => {
    createComponent();

    expect(findTable().exists()).toBe(true);
  });

  it('renders table headers <th>', () => {
    const expectedTableHeaderNames = ['Main feature', 'Sub feature', 'Model name'];

    createComponent();

    expect(findTableHeaders().wrappers.map((h) => h.text())).toEqual(expectedTableHeaderNames);
  });

  describe('when feature settings data is loading', () => {
    it('renders skeleton loaders', () => {
      createComponent({ props: { loading: true } });

      expect(findLoaders().exists()).toBe(true);
    });
  });

  describe('AI feature settings', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('Code Suggestions', () => {
      it('renders Code Suggestions sub-features', () => {
        const rows = findTableRows().wrappers.map((h) => h.text());

        expect(rows.filter((r) => r.includes('Code Generation')).length).toEqual(1);
        expect(rows.filter((r) => r.includes('Code Completion')).length).toEqual(1);
      });
    });

    describe('Duo Chat', () => {
      it('renders Duo Chat', () => {
        const rows = findTableRows().wrappers.map((h) => h.text());

        expect(rows.filter((r) => r.includes('Duo Chat')).length).toEqual(1);
      });
    });
  });
});
