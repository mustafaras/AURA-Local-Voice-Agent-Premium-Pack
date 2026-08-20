import * as vscode from 'vscode';
import { BridgeCommand, BridgeCommandResult, BridgeCommandOutcome, BridgeHealth, SignedEnvelope } from './protocol';
import { BridgeAuthenticator } from './authenticator';
import { BridgeStateCollector } from './stateCollector';
import { Logger } from './logger';

export class CommandHandler {
  private vscode: typeof vscode;
  private extensionID: string;
  private collector: BridgeStateCollector;
  private logger: Logger;

  constructor(
    vscodeModule: typeof vscode,
    extensionID: string,
    collector: BridgeStateCollector,
    logger: Logger
  ) {
    this.vscode = vscodeModule;
    this.extensionID = extensionID;
    this.collector = collector;
    this.logger = logger;
  }

  async handle(
    data: Buffer,
    authenticator: BridgeAuthenticator
  ): Promise<string> {
    const command = await authenticator.validateCommand(data);
    if (!command) {
      const envelope = await authenticator.signResponse('unknown', {
        outcome: 'unavailable',
        message: 'command authentication or freshness check failed'
      });
      return envelope ? JSON.stringify(envelope) : '{}';
    }

    this.logger.log(`handling command: ${command.kind}`);
    const result = await this.execute(command);
    const envelope = await authenticator.signResponse(command.kind, result);
    return envelope ? JSON.stringify(envelope) : '{}';
  }

  private async execute(command: BridgeCommand): Promise<BridgeCommandResult> {
    switch (command.kind) {
      case 'health':
        return this.healthResult('ready');
      case 'workspace':
        return {
          outcome: 'completed',
          message: 'workspace state',
          workspace: {
            folderPaths: this.collector.workspaceFolderPaths(),
            activeFolderPath: this.collector.activeFolderPath()
          }
        };
      case 'editor':
        return {
          outcome: 'completed',
          message: 'editor state',
          editor: this.collector.collect().then((s) => s.editor)
        } as unknown as BridgeCommandResult;
      case 'diagnostics':
        return {
          outcome: 'completed',
          message: 'diagnostics',
          diagnostics: (await this.collector.collect()).diagnostics
        };
      case 'tasks':
        return this.healthResult('ready');
      case 'tests':
        return this.healthResult('ready');
      case 'terminalSessions':
        return this.healthResult('ready');
      case 'runTask':
        return this.runTask(command.name, command.workspacePath);
      case 'cancelTask':
        return this.cancelTask(command.taskID);
      case 'runTests':
        return this.runTests(command.target, command.workspacePath);
      case 'cancelTests':
        return this.cancelTests(command.testID);
      default:
        return this.unavailableResult(`unknown command kind: ${(command as { kind: string }).kind}`);
    }
  }

  private healthResult(state: 'ready'): BridgeCommandResult {
    return {
      outcome: 'completed',
      message: 'bridge health',
      health: BridgeHealth.ready(`extension ${this.extensionID} responding`)
    };
  }

  private async runTask(
    name: string | undefined,
    workspacePath: string | undefined
  ): Promise<BridgeCommandResult> {
    if (!name) {
      return this.unavailableResult('runTask requires a task name');
    }
    try {
      await this.vscode.commands.executeCommand(
        'workbench.action.tasks.runTask',
        name
      );
      return { outcome: 'accepted', message: `task '${name}' accepted` };
    } catch (err) {
      return this.unavailableResult(`could not run task: ${err}`);
    }
  }

  private async cancelTask(
    taskID: string | undefined
  ): Promise<BridgeCommandResult> {
    if (!taskID) {
      return this.unavailableResult('cancelTask requires a task ID');
    }
    try {
      await this.vscode.commands.executeCommand('workbench.action.tasks.terminate');
      return { outcome: 'accepted', message: `task termination requested` };
    } catch (err) {
      return this.unavailableResult(`could not cancel task: ${err}`);
    }
  }

  private async runTests(
    target: string | undefined,
    workspacePath: string | undefined
  ): Promise<BridgeCommandResult> {
    try {
      await this.vscode.commands.executeCommand('workbench.action.debug.start');
      return { outcome: 'accepted', message: 'test run accepted' };
    } catch (err) {
      return this.unavailableResult(`could not run tests: ${err}`);
    }
  }

  private async cancelTests(
    testID: string | undefined
  ): Promise<BridgeCommandResult> {
    try {
      await this.vscode.commands.executeCommand('workbench.action.debug.stop');
      return { outcome: 'accepted', message: 'test stop requested' };
    } catch (err) {
      return this.unavailableResult(`could not cancel tests: ${err}`);
    }
  }

  private unavailableResult(message: string): BridgeCommandResult {
    return {
      outcome: 'unavailable',
      message
    };
  }
}
