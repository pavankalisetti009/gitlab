import { duoChatGlobalState } from '~/super_sidebar/constants';
import { setCookie, getCookie } from '~/lib/utils/common_utils';
import { getStorageValue, saveStorageValue } from '~/lib/utils/local_storage';
import {
  DUO_AGENTIC_MODE_COOKIE,
  DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  CHAT_MODES,
} from 'ee/ai/tanuki_bot/constants';
import { setAiPanelTab } from './graphql';

export const concatStreamedChunks = (arr) => {
  if (!arr) return '';

  let end = arr.findIndex((el) => !el);

  if (end < 0) end = arr.length;

  return arr.slice(0, end).join('');
};

/**
 * Save duo agentic mode preference to both cookie and localStorage.
 * localStorage is used as fallback for mobile/private browsing where cookies may not work.
 *
 * @param {isAgenticMode} Boolean - Value to save
 * @returns {void}
 */
export const saveDuoAgenticModePreference = (isAgenticMode) => {
  setCookie(DUO_AGENTIC_MODE_COOKIE, isAgenticMode, {
    expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  });
  saveStorageValue(DUO_AGENTIC_MODE_COOKIE, isAgenticMode);
};

/**
 * Switch duo chat based on agenticMode value and save to cookie based on
 * saveCookie value.
 *
 * @param {Object} params - The parameters object.
 * @param {boolean} params.agenticMode - The state of the agentic mode (true or false).
 * @param {boolean} params.saveCookie - Flag to save to cookie (true or false).
 * @param {boolean} params.isEmbedded - Flag to indicate if the chat is embedded (true or false).
 * @returns {void}
 */

export const setAgenticMode = ({
  agenticMode = true,
  saveCookie = false,
  isEmbedded = true,
} = {}) => {
  // Update the single source of truth for chat mode
  duoChatGlobalState.chatMode = agenticMode ? CHAT_MODES.AGENTIC : CHAT_MODES.CLASSIC;

  // For drawer mode, also update the legacy isShown/isAgenticChatShown properties
  if (!isEmbedded) {
    duoChatGlobalState.isShown = !agenticMode;
    duoChatGlobalState.isAgenticChatShown = agenticMode;
  }

  if (saveCookie) {
    saveDuoAgenticModePreference(agenticMode);
  }
};

const openChatAndGetState = () => {
  // Get the current chat mode from global state
  const currentMode = duoChatGlobalState.chatMode;
  const isAgenticMode = currentMode === CHAT_MODES.AGENTIC;

  // Set the mode to match current user preference (no change to user's preference)
  setAgenticMode({ agenticMode: isAgenticMode, saveCookie: false, isEmbedded: true });

  // Embedded mode: Open the AI panel to chat tab
  setAiPanelTab('chat');

  return {
    isEmbedded: true,
    currentMode,
    isAgenticMode,
  };
};

/**
 * Sends a command to DuoChat to execute on. This should be use for
 * a single command.
 *
 * External triggers respect the current chat mode (Classic or Agentic) and open
 * the chat in whatever UI mode is currently active (drawer or embedded).
 * In Classic mode, the question (slash command) is executed directly.
 * In Agentic mode, the agenticPrompt is sent as a user message to simulate
 * what the slash command would do.
 *
 * @param {question} String - Prompt to send to the chat endpoint (slash command for Classic mode)
 * @param {resourceId} String - Unique ID to bind the streaming
 * @param {variables} Object - Additional variables to pass to graphql chat mutation
 * @param {agenticPrompt} String - Optional prompt to use in Agentic mode (e.g., "troubleshoot this broken pipeline")
 * @param {agent} Object - Optional agent GraphQL ID  (e.g., { id: "gid://gitlab/Ai::FoundationalChatAgent/security_analyst"})
 */
export const sendDuoChatCommand = ({
  question,
  resourceId,
  variables = {},
  agenticPrompt = null,
  agent = null,
} = {}) => {
  if (!question || !resourceId) {
    throw new Error('Both arguments `question` and `resourceId` are required');
  }

  const { isAgenticMode } = openChatAndGetState();

  window.requestIdleCallback(() => {
    // In Agentic mode, use the agenticPrompt if provided; otherwise fall back to the slash command
    const effectiveQuestion = isAgenticMode && agenticPrompt ? agenticPrompt : question;
    // Add the preferred agent if available when working with agentic mode
    const selectedAgent = isAgenticMode ? agent : null;

    const stateOptions = {
      question: effectiveQuestion,
      resourceId,
      variables,
    };

    if (selectedAgent != null) {
      stateOptions.agent = {
        ...selectedAgent,
        text: selectedAgent.name,
      };
    }

    duoChatGlobalState.commands.push(stateOptions);
  });
};

export const focusDuoChatInput = () => {
  openChatAndGetState();

  duoChatGlobalState.focusChatInput = true;
};

export const clearDuoChatCommands = () => {
  duoChatGlobalState.commands = [];
};

/**
 * Converts a text string into a URL-friendly format for event tracking.
 *
 * - Converts to lowercase
 * - Removes special characters
 * - Replaces spaces with underscores
 * - Limits length to 50 characters
 *
 * @param {string} text - The text to convert
 * @returns {string} The formatted event label
 */
export const generateEventLabelFromText = (text) => {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, '_')
    .substring(0, 50);
};

export const utils = {
  concatStreamedChunks,
  generateEventLabelFromText,
};

export const initializeChatMode = () => {
  const savedModeCookie = getCookie(DUO_AGENTIC_MODE_COOKIE);
  const savedModeStorage = getStorageValue(DUO_AGENTIC_MODE_COOKIE);
  const savedMode = savedModeCookie || (savedModeStorage.exists ? savedModeStorage.value : null);

  // Default to agentic mode unless explicitly disabled via cookie/storage
  if (savedMode !== 'false') {
    duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
  } else {
    duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
  }
};

initializeChatMode();
