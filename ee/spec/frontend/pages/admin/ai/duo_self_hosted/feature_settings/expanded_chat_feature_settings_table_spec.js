import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf, GlAlert, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import ExpandedChatFeatureSettingsTable from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/components/expanded_chat_feature_settings_table.vue';
import getAiFeatureSettingsQuery from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { DUO_MAIN_FEATURES } from 'ee/pages/admin/ai/duo_self_hosted/constants';
import {
  mockAiFeatureSettings,
  mockDuoChatFeatureSettings,
  mockCodeSuggestionsFeatureSettings,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('ExpandedChatFeatureSettingsTable', () => {
  let wrapper;

  const duoConfigurationSettingsPath = '/admin/gitlab_duo/configuration';
  const getAiFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettings: {
        nodes: mockAiFeatureSettings,
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[getAiFeatureSettingsQuery, getAiFeatureSettingsSuccessHandler]],
    injectedProps = {},
    stubs = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = shallowMountExtended(ExpandedChatFeatureSettingsTable, {
      apolloProvider: mockApollo,
      provide: {
        betaModelsEnabled: false,
        duoConfigurationSettingsPath,
        ...injectedProps,
      },
      stubs: { ...stubs },
    });
  };

  const findFeatureSettingsTable = () => wrapper.findComponent(ExpandedChatFeatureSettingsTable);
  const findDuoChatTableRows = () => wrapper.findByTestId('duo-chat-table-rows');
  const findCodeSuggestionsTableRows = () => wrapper.findByTestId('code-suggestions-table-rows');
  const findOtherDuoFeaturesTableRows = () => wrapper.findByTestId('other-duo-features-table-rows');
  const findSectionHeaders = () => wrapper.findAll('h2');
  const findSectionDescriptions = () => wrapper.findAllComponents(GlSprintf);
  const findDuoConfigurationLink = () => wrapper.findByTestId('duo-configuration-link');
  const findBetaAlert = () => wrapper.findComponent(GlAlert);

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettingsTable().exists()).toBe(true);
  });

  it('renders Code Suggestions section', () => {
    createComponent();

    expect(findSectionHeaders().at(0).text()).toBe('Code Suggestions');
    expect(findSectionDescriptions().at(0).attributes('message')).toContain(
      'Assists developers by providing real-time code completions',
    );
    expect(findCodeSuggestionsTableRows().exists()).toBe(true);
  });

  it('renders Duo Chat section', () => {
    createComponent();

    expect(findSectionHeaders().at(1).text()).toBe('GitLab Duo Chat');
    expect(findSectionDescriptions().at(1).attributes('message')).toContain(
      'An AI assistant that provides real-time guidance',
    );
    expect(findDuoChatTableRows().exists()).toBe(true);
  });

  describe('Other GitLab Duo features section', () => {
    it('renders section when there are feature settings to show', async () => {
      createComponent();
      await waitForPromises();

      expect(findSectionHeaders()).toHaveLength(3);
      expect(findSectionHeaders().at(2).text()).toBe('Other GitLab Duo features');
      expect(findOtherDuoFeaturesTableRows().exists()).toBe(true);
    });

    it('does not render section when there are no feature settings to show', async () => {
      const featureSettingsExcludingOtherDuo = [
        ...mockDuoChatFeatureSettings,
        ...mockCodeSuggestionsFeatureSettings,
      ];
      const getFeatureSettingsExcludingOtherDuoSuccessHandler = jest.fn().mockResolvedValue({
        data: {
          aiFeatureSettings: {
            nodes: featureSettingsExcludingOtherDuo,
            errors: [],
          },
        },
      });

      createComponent({
        apolloHandlers: [
          [getAiFeatureSettingsQuery, getFeatureSettingsExcludingOtherDuoSuccessHandler],
        ],
      });
      await waitForPromises();

      expect(findSectionHeaders()).toHaveLength(2);
      expect(findOtherDuoFeaturesTableRows().exists()).toBe(false);
    });
  });

  describe('when feature settings data is loading', () => {
    it('passes the correct loading state to FeatureSettingsTableRows', () => {
      createComponent();

      expect(findCodeSuggestionsTableRows().props('isLoading')).toBe(true);
      expect(findDuoChatTableRows().props('isLoading')).toBe(true);
    });
  });

  describe('when beta features are enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { betaModelsEnabled: true } });
    });

    it('does not display a beta models info alert', () => {
      expect(findBetaAlert().exists()).toBe(false);
    });
  });

  describe('when beta features are disabled', () => {
    it('displays a beta models info alert', () => {
      createComponent({ stubs: { GlLink, GlSprintf } });

      expect(findBetaAlert().exists()).toBe(true);
      expect(findDuoConfigurationLink().attributes('href')).toBe(duoConfigurationSettingsPath);
    });
  });

  describe('when the API query is successful', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes Code Suggestions table row data to FeatureSettingsTableRows', () => {
      expect(findCodeSuggestionsTableRows().props('isLoading')).toEqual(false);
      expect(findCodeSuggestionsTableRows().props('aiFeatureSettings')).toEqual(
        mockAiFeatureSettings.filter(
          (setting) => setting.mainFeature === DUO_MAIN_FEATURES.CODE_SUGGESTIONS,
        ),
      );
    });

    it('passes Duo Chat table row data to FeatureSettingsTableRows', () => {
      expect(findDuoChatTableRows().props('isLoading')).toEqual(false);
      expect(findDuoChatTableRows().props('aiFeatureSettings')).toEqual(
        mockAiFeatureSettings.filter(
          (setting) => setting.mainFeature === DUO_MAIN_FEATURES.DUO_CHAT,
        ),
      );
    });
  });

  describe('when the API request is unsuccessful', () => {
    describe('due to a general error', () => {
      it('displays an error message for feature settings', async () => {
        createComponent({
          apolloHandlers: [[getAiFeatureSettingsQuery, jest.fn().mockRejectedValue('ERROR')]],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the AI feature settings. Please try again.',
          }),
        );
      });
    });

    describe('due to a business logic error', () => {
      const getAiFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiFeatureSettings: {
            errors: ['An error occured'],
          },
        },
      });

      it('displays an error message for feature settings', async () => {
        createComponent({
          apolloHandlers: [[getAiFeatureSettingsQuery, getAiFeatureSettingsErrorHandler]],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the AI feature settings. Please try again.',
          }),
        );
      });
    });
  });
});
