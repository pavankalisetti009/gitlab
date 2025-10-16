// =========================
// Chat functionality types
// =========================
export type ChatModel = {
  text: string;
  value: string;
}

export type ChatEvents = {
  'thread-selected': []
  'new-chat': []
  'back-to-list': []
  'delete-thread': []
  'chat-cancel': []
  'send-chat-prompt': []
  'chat-hidden': []
  'track-feedback': []
  'chat-resize': []
  'change-model': [model: ChatModel['value']]
}

// =========================
// Host communication types
// =========================
export type HostDataProps = {
  models?: ChatModel[];
  avatarUrl?: string;
  userName?: string;
};
