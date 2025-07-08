import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf, GlAlert, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import ExpandedChatFeatureSettingsTable from 'ee/ai/duo_self_hosted/feature_settings/components/expanded_chat_feature_settings_table.vue';
import getAiFeatureSettingsQuery from 'ee/ai/duo_self_hosted/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { mockAiFeatureSettings } from './mock_data';

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
        betaModelsEnabled: true,
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
  const findDuoMergeRequestTableRows = () => wrapper.findByTestId('duo-merge-requests-table-rows');
  const findDuoIssuesTableRows = () => wrapper.findByTestId('duo-issues-table-rows');
  const findSectionHeaders = () => wrapper.findAll('h2');
  const findSectionDescriptions = () => wrapper.findAllComponents(GlSprintf);
  const findDuoConfigurationLink = () => wrapper.findByTestId('duo-configuration-link');
  const findBetaAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(async () => {
    createComponent();

    await waitForPromises();
  });

  it('renders the component', () => {
    expect(findFeatureSettingsTable().exists()).toBe(true);
  });

  it('renders Code Suggestions section', () => {
    expect(findSectionHeaders().at(0).text()).toBe('Code Suggestions');
    expect(findSectionDescriptions().at(0).attributes('message')).toContain(
      'Assists developers by generating and completing code in real-time.',
    );
    expect(findCodeSuggestionsTableRows().exists()).toBe(true);
  });

  it('renders Duo Chat section', () => {
    expect(findSectionHeaders().at(1).text()).toBe('GitLab Duo Chat');
    expect(findSectionDescriptions().at(1).attributes('message')).toContain(
      'An AI assistant that helps users accelerate software development using real-time conversational AI.',
    );
    expect(findDuoChatTableRows().exists()).toBe(true);
  });

  it('renders Duo merge request features section', () => {
    expect(findSectionHeaders().at(2).text()).toBe('GitLab Duo for merge requests');
    expect(findSectionDescriptions().at(2).attributes('message')).toContain(
      'AI-native features that help users accomplish tasks during the lifecycle of a merge request.',
    );
    expect(findDuoMergeRequestTableRows().exists()).toBe(true);
  });

  it('renders Duo issues section', () => {
    expect(findSectionHeaders().at(3).text()).toBe('GitLab Duo for issues');
    expect(findSectionDescriptions().at(3).attributes('message')).toContain(
      'An AI-native feature that generates a summary of discussions on an issue.',
    );
    expect(findDuoIssuesTableRows().exists()).toBe(true);
  });

  it('renders Other Duo features section', () => {
    expect(findSectionHeaders().at(4).text()).toBe('Other GitLab Duo features');
    expect(findSectionDescriptions().at(4).attributes('message')).toContain(
      'AI-native features that support users outside of Chat or Code Suggestions.',
    );
    expect(findOtherDuoFeaturesTableRows().exists()).toBe(true);
  });

  describe('when feature settings data is loading', () => {
    it('passes the correct loading state to FeatureSettingsTableRows', () => {
      createComponent();

      expect(findCodeSuggestionsTableRows().props('isLoading')).toBe(true);
      expect(findDuoChatTableRows().props('isLoading')).toBe(true);
    });
  });

  describe('when beta features are enabled', () => {
    it('does not display a beta models info alert', () => {
      expect(findBetaAlert().exists()).toBe(false);
    });
  });

  describe('when beta features are disabled', () => {
    it('displays a beta models info alert', () => {
      createComponent({
        injectedProps: { betaModelsEnabled: false },
        stubs: { GlLink, GlSprintf },
      });

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

      const tableRowsFeatureSettingsProps =
        findCodeSuggestionsTableRows().props('aiFeatureSettings');
      expect(tableRowsFeatureSettingsProps.map((fs) => [fs.feature, fs.releaseState])).toEqual([
        ['code_generations', 'GA'],
        ['code_completions', 'GA'],
      ]);
    });

    it('passes sorted Duo Chat table row data to FeatureSettingsTableRows', () => {
      expect(findDuoChatTableRows().props('isLoading')).toEqual(false);

      const tableRowsFeatureSettingsProps = findDuoChatTableRows().props('aiFeatureSettings');
      expect(tableRowsFeatureSettingsProps.map((fs) => [fs.feature, fs.releaseState])).toEqual([
        ['duo_chat', 'GA'],
        ['duo_chat_explain_code', 'BETA'],
        ['duo_chat_troubleshoot_job', 'EXPERIMENT'],
      ]);
    });

    it('passes sorted Other Duo Features table row data to FeatureSettingsTableRows', () => {
      expect(findOtherDuoFeaturesTableRows().props('isLoading')).toEqual(false);

      const tableRowsFeatureSettingsProps =
        findOtherDuoFeaturesTableRows().props('aiFeatureSettings');
      expect(tableRowsFeatureSettingsProps.map((fs) => [fs.feature, fs.releaseState])).toEqual([
        ['glab_ask_git_command', 'BETA'],
      ]);
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
