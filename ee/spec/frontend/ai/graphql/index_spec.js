import VueApollo from 'vue-apollo';
import Cookies from '~/lib/utils/cookies';
import createDefaultClient from '~/lib/graphql';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { eventHub, SHOW_SESSION } from 'ee/ai/events/panel';
import {
  setAiPanelTab,
  ACTIVE_TAB_KEY,
  activeTab,
  cacheConfig,
  createApolloProvider,
} from 'ee/ai/graphql';

jest.mock('~/lib/utils/cookies');
jest.mock('~/lib/graphql');
jest.mock('ee/ai/events/panel');
jest.mock('vue-apollo');

describe('AI GraphQL Configuration', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    activeTab(undefined);
    duoChatGlobalState.activeTab = undefined;
  });

  describe('setAiPanelTab', () => {
    describe('when tab value is provided', () => {
      let result;

      beforeEach(() => {
        result = setAiPanelTab('chat');
      });

      it('sets the cookie with the tab value', () => {
        expect(Cookies.set).toHaveBeenCalledWith(ACTIVE_TAB_KEY, 'chat');
      });

      it('updates duoChatGlobalState.activeTab', () => {
        expect(duoChatGlobalState.activeTab).toBe('chat');
      });

      it('updates activeTab reactive variable', () => {
        expect(activeTab()).toBe('chat');
      });

      it('returns the activeTab value', () => {
        expect(result).toBe('chat');
      });
    });

    describe('when tab value is falsy', () => {
      beforeEach(() => {
        duoChatGlobalState.activeTab = 'chat';
        activeTab('chat');
      });

      it.each([
        ['undefined', undefined],
        ['null', null],
        ['empty string', ''],
      ])('handles %s value correctly', (description, falsyValue) => {
        const result = setAiPanelTab(falsyValue);

        expect(Cookies.remove).toHaveBeenCalledWith(ACTIVE_TAB_KEY);
        expect(Cookies.set).not.toHaveBeenCalled();
        expect(duoChatGlobalState.activeTab).toBeUndefined();
        expect(activeTab()).toBeUndefined();
        expect(result).toBeUndefined();
      });
    });
  });

  describe('cacheConfig', () => {
    it('has the correct structure', () => {
      expect(cacheConfig).toMatchObject({
        typePolicies: {
          Query: {
            fields: {
              activeTab: {
                read: expect.any(Function),
              },
            },
          },
        },
      });
    });

    describe('typePolicies.Query.fields.activeTab.read', () => {
      it('returns the current activeTab value', () => {
        activeTab('test-tab');

        const result = cacheConfig.typePolicies.Query.fields.activeTab.read();

        expect(result).toBe('test-tab');
      });
    });
  });

  describe('createApolloProvider', () => {
    let mockClient;
    let eventHandler;

    beforeEach(() => {
      eventHub.$on.mockImplementation((event, handler) => {
        eventHandler = handler;
      });
      mockClient = { query: jest.fn() };
      createDefaultClient.mockReturnValue(mockClient);
      VueApollo.mockImplementation(function MockVueApollo(config) {
        this.defaultClient = config.defaultClient;
      });
    });

    describe('events', () => {
      beforeEach(() => {
        createApolloProvider();
      });

      it('listens to SHOW_SESSION events', () => {
        expect(eventHub.$on).toHaveBeenCalledWith(SHOW_SESSION, expect.any(Function));
      });

      it('sets the active tab when a SHOW_SESSION event is received', () => {
        eventHandler();

        expect(activeTab()).toBe('sessions');
      });
    });

    describe('when cookie exists', () => {
      let provider;

      beforeEach(() => {
        Cookies.get.mockReturnValue('saved-tab');
        provider = createApolloProvider();
      });

      it('initializes activeTab with cookie value', () => {
        expect(Cookies.get).toHaveBeenCalledWith(ACTIVE_TAB_KEY);
        expect(activeTab()).toBe('saved-tab');
      });

      it('calls createDefaultClient with cacheConfig', () => {
        expect(createDefaultClient).toHaveBeenCalledWith({}, { cacheConfig });
      });

      it('creates VueApollo instance with defaultClient', () => {
        expect(VueApollo).toHaveBeenCalledWith({ defaultClient: mockClient });
      });

      it('returns VueApollo instance', () => {
        expect(provider).toBeInstanceOf(VueApollo);
        expect(provider.defaultClient).toBe(mockClient);
      });
    });

    describe('when cookie does not exist', () => {
      let provider;

      beforeEach(() => {
        Cookies.get.mockReturnValue(undefined);
        provider = createApolloProvider();
      });

      it('initializes activeTab as undefined', () => {
        expect(activeTab()).toBeUndefined();
      });

      it('still creates VueApollo instance', () => {
        expect(VueApollo).toHaveBeenCalled();
        expect(provider).toBeInstanceOf(VueApollo);
      });
    });
  });
});
