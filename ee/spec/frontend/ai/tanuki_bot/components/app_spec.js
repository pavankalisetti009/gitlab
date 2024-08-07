import { GlDuoChat } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import { v4 as uuidv4 } from 'uuid';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import { sendDuoChatCommand } from 'ee/ai/utils';
import TanukiBotChatApp from 'ee/ai/tanuki_bot/components/app.vue';
import DuoChatCallout from 'ee/ai/components/global_callout/duo_chat_callout.vue';
import {
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAN_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
} from 'ee/ai/constants';
import { TANUKI_BOT_TRACKING_EVENT_NAME } from 'ee/ai/tanuki_bot/constants';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import aiResponseStreamSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response_stream.subscription.graphql';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import duoUserFeedbackMutation from 'ee/ai/graphql/duo_user_feedback.mutation.graphql';
import getAiMessages from 'ee/ai/graphql/get_ai_messages.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { getMarkdown } from '~/rest_api';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { describeSkipVue3, SkipReason } from 'helpers/vue3_conditional';

import {
  MOCK_USER_MESSAGE,
  MOCK_USER_ID,
  MOCK_RESOURCE_ID,
  MOCK_TANUKI_SUCCESS_RES,
  MOCK_TANUKI_BOT_MUTATATION_RES,
  MOCK_CHAT_CACHED_MESSAGES_RES,
  GENERATE_MOCK_TANUKI_RES,
  MOCK_CHUNK_MESSAGE,
  MOCK_SLASH_COMMANDS,
} from '../mock_data';

Vue.use(Vuex);
Vue.use(VueApollo);

jest.mock('~/rest_api');
jest.mock('uuid');

const skipReason = new SkipReason({
  name: 'GitLab Duo Chat',
  reason: 'Test times out (CPU pegged at 100%)',
  issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/458409',
});

describeSkipVue3(skipReason, () => {
  let wrapper;

  const actionSpies = {
    addDuoChatMessage: jest.fn(),
    setMessages: jest.fn(),
    setLoading: jest.fn(),
  };

  let aiResponseSubscriptionHandler = jest.fn();
  let aiResponseStreamSubscriptionHandler = jest.fn();
  const chatMutationHandlerMock = jest.fn().mockResolvedValue(MOCK_TANUKI_BOT_MUTATATION_RES);
  const duoUserFeedbackMutationHandlerMock = jest.fn().mockResolvedValue({});
  const queryHandlerMock = jest.fn().mockResolvedValue(MOCK_CHAT_CACHED_MESSAGES_RES);

  const feedbackData = {
    feedbackChoices: ['useful', 'not_relevant'],
    didWhat: 'provided clarity',
    improveWhat: 'more examples',
    message: {
      requestId: '1234567890',
      id: 'abcdefgh',
      role: 'user',
      content: 'test',
      extras: {
        exampleExtraContent: 1,
      },
    },
  };

  const findCallout = () => wrapper.findComponent(DuoChatCallout);

  const createComponent = ({
    initialState = {},
    propsData = { userId: MOCK_USER_ID, resourceId: MOCK_RESOURCE_ID },
  } = {}) => {
    const store = new Vuex.Store({
      actions: actionSpies,
      state: {
        ...initialState,
      },
    });

    const apolloProvider = createMockApollo([
      [chatMutation, chatMutationHandlerMock],
      [duoUserFeedbackMutation, duoUserFeedbackMutationHandlerMock],
      [getAiMessages, queryHandlerMock],
    ]);

    apolloProvider.defaultClient.setRequestHandler(
      aiResponseSubscription,
      aiResponseSubscriptionHandler,
    );

    apolloProvider.defaultClient.setRequestHandler(
      aiResponseStreamSubscription,
      aiResponseStreamSubscriptionHandler,
    );

    wrapper = shallowMountExtended(TanukiBotChatApp, {
      store,
      apolloProvider,
      propsData,
    });
  };

  const findGlDuoChat = () => wrapper.findComponent(GlDuoChat);
  let perfTrackingSpy;
  beforeEach(() => {
    uuidv4.mockImplementation(() => '123');
    getMarkdown.mockImplementation(({ text }) => Promise.resolve({ data: { html: text } }));

    performance.mark = jest.fn();
    performance.measure = jest.fn();
    performance.getEntriesByName = jest.fn(() => [{ duration: 123 }]);
    performance.clearMarks = jest.fn();
    performance.clearMeasures = jest.fn();
  });

  afterEach(() => {
    jest.clearAllMocks();
    duoChatGlobalState.commands = [];
    duoChatGlobalState.isShown = false;
    if (wrapper) {
      wrapper.destroy();
    }
  });

  it('generates unique `clientSubscriptionId` using v4', () => {
    createComponent();
    expect(uuidv4).toHaveBeenCalled();
    expect(wrapper.vm.clientSubscriptionId).toBe('123');
  });

  describe('fetching the cached messages', () => {
    it('fetches the cached messages on mount and updates the messages with the returned result', async () => {
      createComponent();
      expect(queryHandlerMock).toHaveBeenCalled();
      await waitForPromises();
      expect(actionSpies.setMessages).toHaveBeenCalledWith(
        expect.anything(),
        MOCK_CHAT_CACHED_MESSAGES_RES.data.aiMessages.nodes,
      );
    });
    it('updates the messages even if the returned result has no messages', async () => {
      queryHandlerMock.mockResolvedValue({
        data: {
          aiMessages: {
            nodes: [],
          },
        },
      });
      createComponent();
      await waitForPromises();
      expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
    });
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
      duoChatGlobalState.isShown = true;
    });

    it('renders the DuoChat component', () => {
      expect(findGlDuoChat().exists()).toBe(true);
    });

    it('sets correct `badge-type` and `badge-help-page-url` props on the chat component', () => {
      expect(findGlDuoChat().props('badgeType')).toBe(null);
    });

    it('passes the correct slashCommands prop to GlDuoChat', () => {
      createComponent();
      expect(findGlDuoChat().props('slashCommands')).toEqual(MOCK_SLASH_COMMANDS);
    });

    it('renders the duo-chat-callout component', () => {
      expect(findCallout().exists()).toBe(true);
    });
  });

  describe('when new commands are added to the global state', () => {
    beforeEach(() => {
      createComponent();
      perfTrackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      performance.mark = jest.fn();
    });

    it('calls the chat mutation', async () => {
      expect(chatMutationHandlerMock).toHaveBeenCalledTimes(0);

      sendDuoChatCommand({ question: '/troubleshoot', resourceId: '1' });
      await waitForPromises();

      expect(chatMutationHandlerMock).toHaveBeenCalledTimes(1);
    });

    it('uses the command resourceId', async () => {
      sendDuoChatCommand({ question: '/troubleshoot', resourceId: 'command::1' });
      await waitForPromises();

      expect(chatMutationHandlerMock).toHaveBeenCalledWith({
        clientSubscriptionId: '123',
        question: '/troubleshoot',
        resourceId: 'command::1',
      });
    });
  });

  describe('events handling', () => {
    beforeEach(() => {
      createComponent();
      duoChatGlobalState.isShown = true;
    });

    describe('@chat-hidden', () => {
      beforeEach(async () => {
        findGlDuoChat().vm.$emit('chat-hidden');
        await nextTick();
      });

      it('closes the chat on @chat-hidden', () => {
        expect(duoChatGlobalState.isShown).toBe(false);
        expect(findGlDuoChat().exists()).toBe(false);
      });
    });

    describe('@send-chat-prompt', () => {
      beforeEach(() => {
        perfTrackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
        performance.mark = jest.fn();
      });

      afterEach(() => {
        unmockTracking();
      });

      it('does set loading to `true` for a message other than the reset or clean ones', () => {
        findGlDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        expect(actionSpies.setLoading).toHaveBeenCalled();
      });

      it('starts the performance measurement when sending a prompt', () => {
        findGlDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        expect(performance.mark).toHaveBeenCalledWith('prompt-sent');
      });

      it.each([GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAN_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
        'does not set loading to `true` for "%s" message',
        async (msg) => {
          actionSpies.setLoading.mockReset();
          findGlDuoChat().vm.$emit('send-chat-prompt', msg);
          await nextTick();
          expect(actionSpies.setLoading).not.toHaveBeenCalled();
        },
      );

      describe.each`
        resourceId          | expectedResourceId
        ${MOCK_RESOURCE_ID} | ${MOCK_RESOURCE_ID}
        ${null}             | ${MOCK_USER_ID}
      `(`with resourceId = $resourceId`, ({ resourceId, expectedResourceId }) => {
        it('calls correct GraphQL mutation with fallback to userId when input is submitted', async () => {
          createComponent({ propsData: { userId: MOCK_USER_ID, resourceId } });
          findGlDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

          await nextTick();

          expect(chatMutationHandlerMock).toHaveBeenCalledWith({
            resourceId: expectedResourceId,
            question: MOCK_USER_MESSAGE.content,
            clientSubscriptionId: '123',
          });
        });

        it('passes correct resourceId or uses userId as a fallback', () => {
          createComponent({
            initialState: { loading: true },
            propsData: { userId: MOCK_USER_ID, resourceId },
          });

          expect(aiResponseStreamSubscriptionHandler).toHaveBeenNthCalledWith(2, {
            userId: MOCK_USER_ID,
            resourceId: expectedResourceId,
            clientSubscriptionId: '123',
          });
        });
      });

      it.each([GENIE_CHAT_CLEAN_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
        'refetches the `aiMessages` if the prompt is "%s" and does not call addDuoChatMessage',
        async (prompt) => {
          createComponent();

          await waitForPromises();

          queryHandlerMock.mockClear();
          actionSpies.addDuoChatMessage.mockClear();

          findGlDuoChat().vm.$emit('send-chat-prompt', prompt);

          await waitForPromises();

          expect(queryHandlerMock).toHaveBeenCalled();
          expect(actionSpies.addDuoChatMessage).not.toHaveBeenCalled();
        },
      );

      describe('tracking on mutation', () => {
        let trackingSpy;

        beforeEach(() => {
          trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
        });

        afterEach(() => {
          unmockTracking();
        });

        it('tracks the submission for prompts by default', async () => {
          createComponent();
          findGlDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

          await waitForPromises();
          expect(trackingSpy).toHaveBeenCalled();
        });
        it.each([GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAN_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
          'does not track if the sent message is "%s"',
          async (msg) => {
            createComponent();
            findGlDuoChat().vm.$emit('send-chat-prompt', msg);

            await waitForPromises();
            expect(trackingSpy).not.toHaveBeenCalled();
          },
        );
      });
    });

    describe('@track-feedback', () => {
      it('calls the feedback GraphQL mutation when message is passed', async () => {
        createComponent();
        findGlDuoChat().vm.$emit('track-feedback', feedbackData);

        await waitForPromises();
        expect(duoUserFeedbackMutationHandlerMock).toHaveBeenCalledWith({
          input: {
            aiMessageId: feedbackData.message.id,
            trackingEvent: {
              category: TANUKI_BOT_TRACKING_EVENT_NAME,
              action: 'click_button',
              label: 'response_feedback',
              property: 'useful,not_relevant',
              extra: {
                improveWhat: 'more examples',
                didWhat: 'provided clarity',
                prompt_location: 'after_content',
              },
            },
          },
        });
      });

      it('updates Vuex store correctly when message is passed', async () => {
        createComponent();
        findGlDuoChat().vm.$emit('track-feedback', feedbackData);

        await waitForPromises();
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.any(Object),
          expect.objectContaining({
            requestId: feedbackData.message.requestId,
            role: feedbackData.message.role,
            content: feedbackData.message.content,
            extras: { ...feedbackData.message.extras, hasFeedback: true },
          }),
        );
      });
    });
  });

  describe('Error conditions', () => {
    const errorText = 'Fancy foo';

    it('does call addDuoChatMessage', async () => {
      queryHandlerMock.mockImplementationOnce(() => Promise.reject(new Error(errorText)));
      duoChatGlobalState.isShown = true;
      createComponent();
      await waitForPromises();
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          errors: [`Error: ${errorText}`],
        }),
      );
    });

    describe('when mutation fails', () => {
      it('throws an error, but still calls addDuoChatMessage', async () => {
        chatMutationHandlerMock.mockRejectedValue(new Error(errorText));
        duoChatGlobalState.isShown = true;
        createComponent();
        await waitForPromises();
        findGlDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: MOCK_USER_MESSAGE.content,
          }),
        );
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            errors: [`Error: ${errorText}`],
          }),
        );
      });
    });
  });

  describe('Subscriptions', () => {
    let mockSubscriptionComplete;
    let mockSubscriptionStream;

    beforeEach(() => {
      mockSubscriptionComplete = createMockSubscription();
      mockSubscriptionStream = createMockSubscription();
      aiResponseSubscriptionHandler = () => mockSubscriptionComplete;
      aiResponseStreamSubscriptionHandler = () => mockSubscriptionStream;
    });

    afterEach(() => {
      duoChatGlobalState.isShown = false;
      if (wrapper) {
        wrapper.destroy();
      }
      jest.clearAllMocks();
    });

    it('activates subscriptions when isShown is true', async () => {
      duoChatGlobalState.isShown = true;
      createComponent();
      await waitForPromises();

      expect(mockSubscriptionComplete.closed).toBe(false);
      expect(mockSubscriptionStream.closed).toBe(false);
    });

    it('does not activate subscriptions when isShown is false', async () => {
      duoChatGlobalState.isShown = false;
      createComponent();
      await waitForPromises();

      expect(mockSubscriptionComplete.closed).toBe(true);
      expect(mockSubscriptionStream.closed).toBe(true);
    });

    it('stops adding new messages when more chunks with the same request ID come in after the full message has already been received', async () => {
      const requestId = '123';
      const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1, requestId);
      const secondChunk = MOCK_CHUNK_MESSAGE('second chunk', 2, requestId);
      const successResponse = GENERATE_MOCK_TANUKI_RES('', requestId);

      duoChatGlobalState.isShown = true;

      createComponent();
      await waitForPromises();

      // message chunk streaming in
      mockSubscriptionStream.next(firstChunk);
      await waitForPromises();
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(1);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.any(Object),
        firstChunk.data.aiCompletionResponse,
      );

      // full message being sent
      mockSubscriptionComplete.next(successResponse);
      await waitForPromises();
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(2);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.any(Object),
        successResponse.data.aiCompletionResponse,
      );

      // another chunk with the same request ID
      mockSubscriptionStream.next(secondChunk);
      await waitForPromises();
      // checking that addDuoChatMessage was not called again since full message was already being sent
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(2);
    });

    it('clears the commands when streaming is done', async () => {
      const requestId = '123';
      const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1, requestId);
      const successResponse = GENERATE_MOCK_TANUKI_RES('', requestId);

      duoChatGlobalState.isShown = true;

      expect(duoChatGlobalState.commands).toHaveLength(0);
      sendDuoChatCommand({ question: '/troubleshoot', resourceId: '1' });
      expect(duoChatGlobalState.commands).toHaveLength(1);

      createComponent();
      await waitForPromises();

      // message chunk streaming in
      mockSubscriptionStream.next(firstChunk);
      await waitForPromises();
      // No changes to commands
      expect(duoChatGlobalState.commands).toHaveLength(1);

      // full message being sent
      mockSubscriptionComplete.next(successResponse);
      await waitForPromises();
      await waitForPromises();

      // commands have been cleared out
      expect(duoChatGlobalState.commands).toHaveLength(0);
    });

    it('continues to invoke addDuoChatMessage when a new message chunk arrives with a distinct request ID, even after a complete message has been received', async () => {
      const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1);
      const firstChunkNewRequest = MOCK_CHUNK_MESSAGE('first chunk', 2, 2);

      duoChatGlobalState.isShown = true;
      createComponent();
      await waitForPromises();

      // message chunk streaming in
      mockSubscriptionStream.next(firstChunk);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.any(Object),
        firstChunk.data.aiCompletionResponse,
      );

      // full message being sent
      mockSubscriptionComplete.next(MOCK_TANUKI_SUCCESS_RES);
      await waitForPromises();
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(2);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.any(Object),
        MOCK_TANUKI_SUCCESS_RES.data.aiCompletionResponse,
      );

      // another chunk with a new request ID
      mockSubscriptionStream.next(firstChunkNewRequest);
      await waitForPromises();
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(3);
    });

    it('stops streaming in new chunks when requestId was canceled', async () => {
      const requestId = '123';
      const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1, requestId);
      const secondChunk = MOCK_CHUNK_MESSAGE('second chunk', 2, requestId);

      duoChatGlobalState.isShown = true;

      createComponent({
        initialState: {
          messages: [
            {
              requestId,
            },
          ],
        },
      });
      await waitForPromises();
      perfTrackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      // message chunk streaming in
      mockSubscriptionStream.next(firstChunk);
      await waitForPromises();
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(1);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.any(Object),
        firstChunk.data.aiCompletionResponse,
      );

      findGlDuoChat().vm.$emit('chat-cancel');

      // another chunk with the same request ID
      mockSubscriptionStream.next(secondChunk);
      await waitForPromises();
      // checking that addDuoChatMessage was not called again since request id was canceled
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(1);
    });

    it('stops adding new message when requestId was canceled', async () => {
      const requestId = '123';

      duoChatGlobalState.isShown = true;
      createComponent({
        initialState: {
          messages: [
            {
              requestId,
            },
          ],
        },
      });
      await waitForPromises();

      findGlDuoChat().vm.$emit('chat-cancel');

      // full message being sent
      mockSubscriptionComplete.next(GENERATE_MOCK_TANUKI_RES('', requestId));
      await waitForPromises();
      // checking that addDuoChatMessage was not called since request id was canceled
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(0);
    });

    it('tracks performance metrics correctly when a chunk is received', async () => {
      const chunkMessage = MOCK_CHUNK_MESSAGE('chunk content', 1, 'requestId-123');

      duoChatGlobalState.isShown = true;
      createComponent();
      perfTrackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

      await waitForPromises();

      mockSubscriptionStream.next(chunkMessage);

      expect(performance.mark).toHaveBeenCalledWith('response-received');
      expect(performance.measure).toHaveBeenCalledWith(
        'prompt-to-response',
        'prompt-sent',
        'response-received',
      );
      expect(performance.getEntriesByName).toHaveBeenCalledWith('prompt-to-response');
      expect(performance.clearMarks).toHaveBeenCalled();
      expect(performance.clearMeasures).toHaveBeenCalled();

      expect(perfTrackingSpy).toHaveBeenCalledWith(undefined, 'ai_response_time', {
        property: chunkMessage.data.aiCompletionResponse.requestId,
        value: 123,
      });
    });
  });
});
