import * as vscode from 'vscode';
import { BridgeSnapshot, VSCodeEditorState, VSCodeTerminalState, VSCodeDiagnostic, BridgeHealth } from './protocol';

export class BridgeStateCollector {
  private vscode: typeof vscode;
  private extensionID: string;

  constructor(vscodeModule: typeof vscode, extensionID: string) {
    this.vscode = vscodeModule;
    this.extensionID = extensionID;
  }

  async collect(): Promise<BridgeSnapshot> {
    const editor = this.collectEditor();
    const terminal = this.collectTerminal();
    const diagnostics = this.collectDiagnostics();
    const folderPaths = this.workspaceFolderPaths();
    const activeFolder = folderPaths.length > 0 ? folderPaths[0] : undefined;

    return {
      editor,
      terminal,
      diagnostics,
      tasks: [],
      tests: [],
      terminals: terminal ? [terminal] : [],
      timestamp: new Date().toISOString(),
      health: BridgeHealth.ready(`extension ${this.extensionID} active`)
    };
  }

  workspaceFolderPaths(): string[] {
    if (!this.vscode.workspace.workspaceFolders) return [];
    return this.vscode.workspace.workspaceFolders.map((f) => f.uri.fsPath);
  }

  activeFolderPath(): string | undefined {
    const folders = this.workspaceFolderPaths();
    return folders.length > 0 ? folders[0] : undefined;
  }

  private collectEditor(): VSCodeEditorState | undefined {
    const editor = this.vscode.window.activeTextEditor;
    if (!editor) return undefined;
    const doc = editor.document;
    return {
      activeFilePath: doc.fileName,
      languageID: doc.languageId,
      isDirty: doc.isDirty,
      workspaceFolderPaths: this.workspaceFolderPaths()
    };
  }

  private collectTerminal(): VSCodeTerminalState | undefined {
    const terminal = this.vscode.window.activeTerminal;
    if (!terminal) return undefined;
    // VS Code does not expose cwd or shell directly; report what we have.
    return {
      terminalID: `${terminal.name}`,
      shell: 'unknown',
      workingDirectory: this.activeFolderPath() ?? 'unknown'
    };
  }

  private collectDiagnostics(): VSCodeDiagnostic[] {
    const result: VSCodeDiagnostic[] = [];
    const all = this.vscode.languages.getDiagnostics();
    for (const [uri, diagnostics] of all) {
      for (const d of diagnostics) {
        result.push({
          filePath: uri.fsPath,
          line: Math.max(0, d.range.start.line),
          column: Math.max(0, d.range.start.character),
          severity: mapSeverity(d.severity),
          message: d.message,
          source: d.source
        });
      }
    }
    return result.slice(0, 256);
  }
}

function mapSeverity(s: vscode.DiagnosticSeverity): VSCodeDiagnostic['severity'] {
  switch (s) {
    case vscode.DiagnosticSeverity.Error: return 'error';
    case vscode.DiagnosticSeverity.Warning: return 'warning';
    case vscode.DiagnosticSeverity.Information: return 'information';
    default: return 'hint';
  }
}
