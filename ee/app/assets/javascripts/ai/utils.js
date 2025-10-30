import { duoChatGlobalState } from '~/super_sidebar/constants';
import { setCookie, getCookie } from '~/lib/utils/common_utils';
import {
  DUO_AGENTIC_MODE_COOKIE,
  DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  CHAT_MODES,
} from 'ee/ai/tanuki_bot/constants';

// Initialize chatMode from cookie on module load
const savedMode = getCookie(DUO_AGENTIC_MODE_COOKIE);
if (savedMode === 'true') {
  duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
} else {
  duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
}

export const concatStreamedChunks = (arr) => {
  if (!arr) return '';

  let end = arr.findIndex((el) => !el);

  if (end < 0) end = arr.length;

  return arr.slice(0, end).join('');
};

/**
 * setCookie wrapper with duo agentic mode constances.
 *
 * @param {isAgenticMode} Boolean - Value to save
 * @returns {void}
 */
export const saveDuoAgenticModePreference = (isAgenticMode) => {
  setCookie(DUO_AGENTIC_MODE_COOKIE, isAgenticMode, {
    expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  });
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
  isEmbedded = false,
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
 */
export const sendDuoChatCommand = ({
  question,
  resourceId,
  variables = {},
  agenticPrompt = null,
} = {}) => {
  if (!question || !resourceId) {
    throw new Error('Both arguments `question` and `resourceId` are required');
  }

  // Check if project studio (new design with embedded panel) is enabled
  const isEmbedded = window.gon?.features?.projectStudioEnabled === true;

  // Get the current chat mode from global state
  const currentMode = duoChatGlobalState.chatMode;
  const isAgenticMode = currentMode === CHAT_MODES.AGENTIC;

  // Set the mode to match current user preference (no change to user's preference)
  setAgenticMode({ agenticMode: isAgenticMode, saveCookie: false, isEmbedded });

  if (isEmbedded) {
    // Embedded mode: Open the AI panel to chat tab
    duoChatGlobalState.activeTab = 'chat';
  } else {
    // Drawer mode: Open the appropriate chat based on current mode
    duoChatGlobalState.isShown = !isAgenticMode;
    duoChatGlobalState.isAgenticChatShown = isAgenticMode;
  }

  window.requestIdleCallback(() => {
    // In Agentic mode, use the agenticPrompt if provided; otherwise fall back to the slash command
    const effectiveQuestion = isAgenticMode && agenticPrompt ? agenticPrompt : question;

    duoChatGlobalState.commands.push({
      question: effectiveQuestion,
      resourceId,
      variables,
    });
  });
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
