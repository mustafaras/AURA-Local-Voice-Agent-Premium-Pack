import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { BridgeAuthenticator } from './authenticator';
import { BridgeStateCollector } from './stateCollector';
import { CommandHandler } from './commandHandler';
import { Logger } from './logger';
import { BridgeHealth, ProtocolVersion } from './protocol';

export async function activate(context: vscode.ExtensionContext): Promise<void> {
  const logger = new Logger(vscode.window.createOutputChannel('AURA Bridge'));
  logger.log(`AURA bridge extension activating (protocol ${ProtocolVersion})`);

  const config = vscode.workspace.getConfiguration('auraBridge');
  const statePath = readRequiredPath(config, 'statePath', logger);
  const commandPath = readRequiredPath(config, 'commandPath', logger);
  const responsePath = readRequiredPath(config, 'responsePath', logger);
  const extensionID = readString(config, 'extensionID', 'aura.aura-vscode-extension');
  const intervalSeconds = readNumber(config, 'snapshotIntervalSeconds', 5);

  if (!statePath || !commandPath || !responsePath) {
    logger.log('bridge paths are not configured; extension remains inactive');
    return;
  }

  const secretStorage = context.secrets;
  const authenticator = new BridgeAuthenticator(extensionID, secretStorage, logger);
  const collector = new BridgeStateCollector(vscode, extensionID);
  const handler = new CommandHandler(vscode, extensionID, collector, logger);

  // Ensure parent directories exist so the Swift side can read immediately.
  ensureParentDir(statePath);
  ensureParentDir(commandPath);
  ensureParentDir(responsePath);

  let stopCommandWatch = watchFile(commandPath, async (data) => {
    const result = await handler.handle(data, authenticator);
    await writeAtomic(responsePath, result, logger);
  }, logger);

  let stopSnapshotLoop = startSnapshotLoop(
    async () => {
      try {
        const snapshot = await collector.collect();
        const envelope = await authenticator.signSnapshot(snapshot);
        if (envelope) {
          await writeAtomic(statePath, JSON.stringify(envelope), logger);
        }
      } catch (err) {
        logger.log(`snapshot failed: ${err}`);
      }
    },
    intervalSeconds * 1000,
    logger
  );

  const provision = async () => {
    const value = await vscode.window.showInputBox({
      prompt: 'Enter the AURA bridge shared secret shown in AURA',
      password: true,
      ignoreFocusOut: true,
      validateInput: (v) => v.length >= 16 ? null : 'secret must be at least 16 characters'
    });
    if (value) {
      await authenticator.provision(value);
      vscode.window.showInformationMessage('AURA bridge secret saved');
    }
  };

  const revoke = async () => {
    await authenticator.revoke();
    vscode.window.showInformationMessage('AURA bridge secret removed');
  };

  const health = async () => {
    const hasSecret = await authenticator.hasSecret();
    const configured = `state=${statePath}\ncommand=${commandPath}\nresponse=${responsePath}`;
    vscode.window.showInformationMessage(
      `AURA bridge: secret=${hasSecret ? 'present' : 'missing'}\n${configured}`
    );
  };

  context.subscriptions.push(
    vscode.commands.registerCommand('auraBridge.provision', provision),
    vscode.commands.registerCommand('auraBridge.revoke', revoke),
    vscode.commands.registerCommand('auraBridge.health', health),
    { dispose: () => { stopCommandWatch(); stopSnapshotLoop(); } }
  );

  // Write an initial health envelope so AURA can see the extension is installed
  // even before provisioning.
  try {
    const healthEnvelope = await authenticator.signHealth(BridgeHealth.unauthorized('not provisioned'));
    if (healthEnvelope) {
      await writeAtomic(statePath, JSON.stringify(healthEnvelope), logger);
    }
  } catch (err) {
    logger.log(`initial health write failed: ${err}`);
  }
}

export function deactivate(): void {
  // Stops are handled by disposables registered during activation.
}

function readString(config: vscode.WorkspaceConfiguration, key: string, fallback: string): string {
  const value = config.get<string>(key);
  return value && value.trim().length > 0 ? value.trim() : fallback;
}

function readNumber(config: vscode.WorkspaceConfiguration, key: string, fallback: number): number {
  const value = config.get<number>(key);
  return typeof value === 'number' && value > 0 ? value : fallback;
}

function readRequiredPath(
  config: vscode.WorkspaceConfiguration,
  key: string,
  logger: Logger
): string | undefined {
  const value = config.get<string>(key);
  if (!value || value.trim().length === 0) {
    logger.log(`missing required path: ${key}`);
    return undefined;
  }
  return value.trim();
}

function ensureParentDir(filePath: string): void {
  const parent = path.dirname(filePath);
  if (!fs.existsSync(parent)) {
    fs.mkdirSync(parent, { recursive: true });
  }
}

async function writeAtomic(filePath: string, content: string, logger: Logger): Promise<void> {
  const temp = `${filePath}.tmp`;
  try {
    await fs.promises.writeFile(temp, content, { encoding: 'utf8', mode: 0o600 });
    await fs.promises.rename(temp, filePath);
  } catch (err) {
    logger.log(`writeAtomic failed for ${filePath}: ${err}`);
    throw err;
  }
}

function watchFile(
  filePath: string,
  onData: (data: Buffer) => Promise<void>,
  logger: Logger
): () => void {
  let lastSize = 0;
  let lastModified = 0;

  const check = async () => {
    try {
      const stat = await fs.promises.stat(filePath);
      if (stat.size === 0 || (stat.size === lastSize && stat.mtimeMs === lastModified)) {
        return;
      }
      lastSize = stat.size;
      lastModified = stat.mtimeMs;
      const data = await fs.promises.readFile(filePath);
      if (data.length > 0) {
        await onData(data);
      }
    } catch (err) {
      if ((err as NodeJS.ErrnoException).code !== 'ENOENT') {
        logger.log(`watch ${filePath} error: ${err}`);
      }
    }
  };

  const interval = setInterval(check, 500);
  return () => clearInterval(interval);
}

function startSnapshotLoop(
  fn: () => Promise<void>,
  periodMs: number,
  logger: Logger
): () => void {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try { await fn(); } catch (err) { logger.log(`snapshot loop error: ${err}`); }
    running = false;
  };
  tick();
  const interval = setInterval(tick, periodMs);
  return () => clearInterval(interval);
}

export type { Logger };
