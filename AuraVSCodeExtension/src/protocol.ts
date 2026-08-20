export const ProtocolVersion = 1;

export interface VSCodeEditorState {
  activeFilePath?: string;
  languageID?: string;
  isDirty?: boolean;
  workspaceFolderPaths: string[];
}

export interface VSCodeTerminalState {
  terminalID?: string;
  shell: string;
  workingDirectory: string;
}

export interface VSCodeDiagnostic {
  filePath: string;
  line: number;
  column: number;
  severity: 'error' | 'warning' | 'information' | 'hint';
  message: string;
  source?: string;
}

export interface VSCodeTaskInfo {
  name: string;
  state: string;
  detail?: string;
}

export interface VSCodeTestInfo {
  testID: string;
  state: string;
  detail?: string;
}

export interface BridgeHealth {
  state: 'ready' | 'degraded' | 'disconnected' | 'unauthorized' | 'versionMismatch';
  protocolVersion: number;
  extensionID?: string;
  detail: string;
  observedAt: string;
}

export interface BridgeSnapshot {
  editor?: VSCodeEditorState;
  terminal?: VSCodeTerminalState;
  diagnostics: VSCodeDiagnostic[];
  tasks?: VSCodeTaskInfo[];
  tests?: VSCodeTestInfo[];
  terminals?: VSCodeTerminalState[];
  timestamp: string;
  health?: BridgeHealth;
}

export interface BridgeCommand {
  kind:
    | 'health'
    | 'workspace'
    | 'editor'
    | 'diagnostics'
    | 'tasks'
    | 'tests'
    | 'terminalSessions'
    | 'runTask'
    | 'cancelTask'
    | 'runTests'
    | 'cancelTests';
  name?: string;
  target?: string;
  workspacePath?: string;
  taskID?: string;
  testID?: string;
}

export type BridgeCommandOutcome = 'accepted' | 'completed' | 'cancelled' | 'unavailable';

export interface BridgeCommandResult {
  outcome: BridgeCommandOutcome;
  message: string;
  health?: BridgeHealth;
  workspace?: { folderPaths: string[]; activeFolderPath?: string };
  editor?: VSCodeEditorState;
  diagnostics?: VSCodeDiagnostic[];
  tasks?: VSCodeTaskInfo[];
  tests?: VSCodeTestInfo[];
  terminals?: VSCodeTerminalState[];
}

export interface SignedEnvelope {
  payload: unknown;
  authenticationTag: string;
}

export const BridgeHealth = {
  ready: (detail: string): BridgeHealth => ({
    state: 'ready',
    protocolVersion: ProtocolVersion,
    detail,
    observedAt: new Date().toISOString()
  }),
  degraded: (detail: string): BridgeHealth => ({
    state: 'degraded',
    protocolVersion: ProtocolVersion,
    detail,
    observedAt: new Date().toISOString()
  }),
  disconnected: (detail: string): BridgeHealth => ({
    state: 'disconnected',
    protocolVersion: ProtocolVersion,
    detail,
    observedAt: new Date().toISOString()
  }),
  unauthorized: (detail: string): BridgeHealth => ({
    state: 'unauthorized',
    protocolVersion: ProtocolVersion,
    detail,
    observedAt: new Date().toISOString()
  }),
  versionMismatch: (detail: string): BridgeHealth => ({
    state: 'versionMismatch',
    protocolVersion: ProtocolVersion,
    detail,
    observedAt: new Date().toISOString()
  })
};
