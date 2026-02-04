import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initDuoPanel } from 'ee/ai/init_duo_panel';
import { setAgenticMode } from 'ee/ai/utils';
import DuoAgenticChat from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat.vue';
import DuoChat from 'ee/ai/tanuki_bot/components/duo_chat.vue';

Vue.use(VueApollo);

jest.mock('ee/ai/utils', () => ({
  setAgenticMode: jest.fn(),
  activeWorkItemIds: {
    value: [],
  },
}));

jest.mock('ee/ai/duo_agents_platform/router/ai_panel_router', () => ({
  createRouter: jest.fn(() => {
    const mockRouter = {
      push: jest.fn().mockResolvedValue(true),
      beforeEach: jest.fn(),
    };
    return mockRouter;
  }),
}));

describe('initDuoPanel', () => {
  let el;

  const cleanEl = () => {
    if (el && el.parentNode) {
      el.parentNode.removeChild(el);
    }
  };

  const createDuoPanelElement = (dataset = {}) => {
    cleanEl();
    const element = document.createElement('div');
    element.id = 'duo-chat-panel';
    Object.assign(element.dataset, {
      userId: 'gid://gitlab/User/1',
      projectId: 'gid://gitlab/Project/123',
      namespaceId: 'gid://gitlab/Group/456',
      rootNamespaceId: 'gid://gitlab/Group/789',
      resourceId: 'gid://gitlab/Resource/111',
      metadata: '{"key":"value"}',
      userModelSelectionEnabled: 'false',
      agenticAvailable: 'true',
      classicAvailable: 'true',
      forceAgenticModeForCoreDuoUsers: 'false',
      agenticUnavailableMessage: 'Agentic mode is not available',
      chatTitle: 'GitLab Duo Chat',
      chatDisabledReason: '',
      creditsAvailable: 'true',
      defaultNamespaceSelected: 'true',
      preferencesPath: '/-/profile/preferences',
      ...dataset,
    });
    document.body.appendChild(element);
    return element;
  };

  const createDuoPanelEmptyStateElement = (dataset = {}) => {
    cleanEl();
    const element = document.createElement('div');
    element.id = 'duo-chat-panel-empty-state';
    Object.assign(element.dataset, {
      canStartTrial: 'true',
      newTrialPath: 'newTrialPath',
      trialDuration: '30',
      namespaceType: 'Group',
      ...dataset,
    });
    document.body.appendChild(element);
    return element;
  };

  beforeEach(() => {
    jest.clearAllMocks();
    // Create a mock page layout element
    const pageLayout = document.createElement('div');
    pageLayout.className = 'js-page-layout';
    document.body.appendChild(pageLayout);
  });

  afterEach(() => {
    cleanEl();
    const pageLayout = document.querySelector('.js-page-layout');
    if (pageLayout && pageLayout.parentNode) {
      pageLayout.parentNode.removeChild(pageLayout);
    }
  });

  describe('when duo-chat-panel element does not exist', () => {
    describe('when duo-chat-panel-empty-state element exists', () => {
      beforeEach(createDuoPanelEmptyStateElement);

      it('returns a Vue instance', () => {
        const vueInstance = initDuoPanel();

        expect(vueInstance.$options.name).toBe('AIPanelEmptyStateApp');
      });

      it('extracts all required data attributes', () => {
        const vueInstance = initDuoPanel();

        expect(vueInstance.$options.provide).toEqual({
          canStartTrial: true,
          namespaceType: 'Group',
          newTrialPath: 'newTrialPath',
          trialDuration: '30',
        });
      });
    });

    describe('when the user cannot start a trial', () => {
      beforeEach(() => {
        createDuoPanelEmptyStateElement({ newTrialPath: '' });
      });

      it('computes `canStartTrial` properly', () => {
        const vueInstance = initDuoPanel();

        expect(vueInstance.$options.provide.canStartTrial).toBe(false);
      });
    });

    describe('when duo-chat-panel-empty-state does not exist', () => {
      it('returns false', () => {
        const result = initDuoPanel();
        expect(result).toBe(false);
      });
    });
  });

  describe('when duo-chat-panel element exists', () => {
    beforeEach(() => {
      el = createDuoPanelElement();
    });

    it('returns a Vue instance', () => {
      const vueInstance = initDuoPanel();
      expect(vueInstance).toHaveProperty('$options');
      expect(vueInstance.$options.name).toBe('DuoPanel');
    });

    describe('data attributes parsing', () => {
      it('extracts all required data attributes', () => {
        el = createDuoPanelElement({
          userId: 'gid://gitlab/User/999',
          projectId: 'gid://gitlab/Project/888',
          namespaceId: 'gid://gitlab/Group/777',
          rootNamespaceId: 'gid://gitlab/Group/666',
          resourceId: 'gid://gitlab/Resource/555',
          metadata: '{"custom":"data"}',
          userModelSelectionEnabled: 'true',
        });

        const vueInstance = initDuoPanel();
        const aiPanelProps = vueInstance.$children[0].$props;

        expect(aiPanelProps.userId).toBe('gid://gitlab/User/999');
        expect(aiPanelProps.projectId).toBe('gid://gitlab/Project/888');
        expect(aiPanelProps.namespaceId).toBe('gid://gitlab/Group/777');
        expect(aiPanelProps.rootNamespaceId).toBe('gid://gitlab/Group/666');
        expect(aiPanelProps.resourceId).toBe('gid://gitlab/Resource/555');
        expect(aiPanelProps.metadata).toBe('{"custom":"data"}');
        expect(aiPanelProps.userModelSelectionEnabled).toBe(true);
      });
    });

    describe('chat configuration', () => {
      it('provides chat configuration with agentic and classic components', () => {
        el = createDuoPanelElement();
        const vueInstance = initDuoPanel();

        // Access the AIPanel component which is the first child
        const aiPanel = vueInstance.$children[0];
        expect(aiPanel.chatConfiguration.agenticComponent).toBe(DuoAgenticChat);
        expect(aiPanel.chatConfiguration.classicComponent).toBe(DuoChat);
      });

      it('sets correct chat titles', () => {
        el = createDuoPanelElement({
          chatTitle: 'Custom Chat Title',
        });

        const vueInstance = initDuoPanel();

        const aiPanel = vueInstance.$children[0];
        expect(aiPanel.chatConfiguration.agenticTitle).toBe('Custom Chat Title');
        expect(aiPanel.chatConfiguration.classicTitle).toBeDefined();
      });

      it('includes default props in chat configuration', () => {
        el = createDuoPanelElement({
          userId: 'gid://gitlab/User/123',
          projectId: 'gid://gitlab/Project/456',
          userModelSelectionEnabled: 'true',
          agenticAvailable: 'true',
          classicAvailable: 'false',
          creditsAvailable: 'false',
        });

        const vueInstance = initDuoPanel();

        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;
        expect(defaultProps.userId).toBe('gid://gitlab/User/123');
        expect(defaultProps.projectId).toBe('gid://gitlab/Project/456');
        expect(defaultProps.userModelSelectionEnabled).toBe(true);
        expect(defaultProps.isAgenticAvailable).toBe(true);
        expect(defaultProps.isClassicAvailable).toBe(false);
        expect(defaultProps.creditsAvailable).toBe(false);
        expect(defaultProps.isEmbedded).toBe(true);
      });
    });

    describe('agentic mode initialization', () => {
      it('does not set agentic mode when forceAgenticModeForCoreDuoUsers is false', () => {
        el = createDuoPanelElement({
          forceAgenticModeForCoreDuoUsers: 'false',
        });

        initDuoPanel();
        expect(setAgenticMode).not.toHaveBeenCalled();
      });

      it('sets agentic mode when forceAgenticModeForCoreDuoUsers is true', () => {
        el = createDuoPanelElement({
          forceAgenticModeForCoreDuoUsers: 'true',
        });

        initDuoPanel();
        expect(setAgenticMode).toHaveBeenCalledWith({
          agenticMode: true,
          saveCookie: true,
        });
      });
    });

    describe('Vue instance configuration', () => {
      it('sets the component name to DuoPanel', () => {
        el = createDuoPanelElement();
        const vueInstance = initDuoPanel();

        expect(vueInstance.$options.name).toBe('DuoPanel');
      });

      it('provides isSidePanelView as true', () => {
        el = createDuoPanelElement();
        const vueInstance = initDuoPanel();

        // isSidePanelView is provided to child components, check it's in the provide
        expect(vueInstance.$options.provide.isSidePanelView).toBe(true);
      });

      it('initializes with store', () => {
        el = createDuoPanelElement();
        const vueInstance = initDuoPanel();

        expect(vueInstance.$store).toBeDefined();
      });

      it('initializes with router', () => {
        el = createDuoPanelElement();
        const vueInstance = initDuoPanel();

        // In Vue 3 compat mode, the router is attached to the instance
        expect(vueInstance.$options.router).toBeDefined();
      });
    });

    describe('creditsAvailable attribute', () => {
      it('defaults to true when not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.creditsAvailable;

        const vueInstance = initDuoPanel();

        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;
        expect(defaultProps.creditsAvailable).toBe(true);
      });

      it('parses creditsAvailable as boolean when provided', () => {
        el = createDuoPanelElement({
          creditsAvailable: 'false',
        });

        const vueInstance = initDuoPanel();

        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;
        expect(defaultProps.creditsAvailable).toBe(false);
      });
    });

    describe('defaultNamespaceSelected attribute', () => {
      it('parses defaultNamespaceSelected as boolean true', () => {
        el = createDuoPanelElement({
          defaultNamespaceSelected: 'true',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.defaultNamespaceSelected).toBe(true);
      });

      it('parses defaultNamespaceSelected as boolean false', () => {
        el = createDuoPanelElement({
          defaultNamespaceSelected: 'false',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.defaultNamespaceSelected).toBe(false);
      });

      it('defaults to false when defaultNamespaceSelected is not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.defaultNamespaceSelected;

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.defaultNamespaceSelected).toBe(false);
      });
    });

    describe('preferencesPath attribute', () => {
      it('extracts preferencesPath from dataset', () => {
        el = createDuoPanelElement({
          preferencesPath: '/-/profile/preferences',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.preferencesPath).toBe('/-/profile/preferences');
      });

      it('sets preferencesPath to undefined when not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.preferencesPath;

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.preferencesPath).toBeUndefined();
      });
    });

    describe('isTrial attribute', () => {
      it('parses isTrial as boolean true', () => {
        el = createDuoPanelElement({
          isTrial: 'true',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.isTrial).toBe(true);
      });

      it('parses isTrial as boolean false', () => {
        el = createDuoPanelElement({
          isTrial: 'false',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.isTrial).toBe(false);
      });

      it('defaults to false when isTrial is not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.isTrial;

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.isTrial).toBe(false);
      });
    });

    describe('buyAddonPath attribute', () => {
      it('extracts buyAddonPath from dataset', () => {
        el = createDuoPanelElement({
          buyAddonPath: '/groups/test/-/billings',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.buyAddonPath).toBe('/groups/test/-/billings');
      });

      it('sets buyAddonPath to undefined when not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.buyAddonPath;

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.buyAddonPath).toBeUndefined();
      });
    });

    describe('canBuyAddon attribute', () => {
      it('parses canBuyAddon as boolean true', () => {
        el = createDuoPanelElement({
          canBuyAddon: 'true',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.canBuyAddon).toBe(true);
      });

      it('parses canBuyAddon as boolean false', () => {
        el = createDuoPanelElement({
          canBuyAddon: 'false',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.canBuyAddon).toBe(false);
      });

      it('defaults to false when canBuyAddon is not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.canBuyAddon;

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.canBuyAddon).toBe(false);
      });
    });
  });
});
