import * as crypto from 'crypto';
import * as vscode from 'vscode';
import { Logger } from './logger';
import { BridgeSnapshot, BridgeCommand, BridgeCommandResult, BridgeHealth, SignedEnvelope, ProtocolVersion } from './protocol';

export class BridgeAuthenticator {
  private secretKey?: Buffer;
  private extensionID: string;
  private secretStorage: vscode.SecretStorage;
  private logger: Logger;
  private static readonly secretKeyName = 'aura-bridge-shared-secret';

  constructor(
    extensionID: string,
    secretStorage: vscode.SecretStorage,
    logger: Logger
  ) {
    this.extensionID = extensionID;
    this.secretStorage = secretStorage;
    this.logger = logger;
  }

  async provision(sharedSecret: string): Promise<void> {
    if (sharedSecret.length < 16) {
      throw new Error('shared secret must be at least 16 characters');
    }
    await this.secretStorage.store(BridgeAuthenticator.secretKeyName, sharedSecret);
    this.secretKey = Buffer.from(sharedSecret, 'utf8');
  }

  async revoke(): Promise<void> {
    this.secretKey = undefined;
    await this.secretStorage.delete(BridgeAuthenticator.secretKeyName);
  }

  async hasSecret(): Promise<boolean> {
    if (this.secretKey) return true;
    const stored = await this.secretStorage.get(BridgeAuthenticator.secretKeyName);
    return stored !== undefined && stored.length > 0;
  }

  private async loadSecret(): Promise<Buffer | undefined> {
    if (this.secretKey) return this.secretKey;
    const stored = await this.secretStorage.get(BridgeAuthenticator.secretKeyName);
    if (stored) {
      this.secretKey = Buffer.from(stored, 'utf8');
      return this.secretKey;
    }
    return undefined;
  }

  async signSnapshot(snapshot: BridgeSnapshot): Promise<SignedEnvelope | undefined> {
    const secret = await this.loadSecret();
    if (!secret) return undefined;
    const nonce = crypto.randomBytes(16).toString('hex');
    const issuedAt = new Date();
    const expiresAt = new Date(issuedAt.getTime() + 30_000);
    const payload = {
      protocolVersion: ProtocolVersion,
      extensionID: this.extensionID,
      nonce,
      issuedAt: issuedAt.toISOString(),
      expiresAt: expiresAt.toISOString(),
      snapshot
    };
    return {
      payload,
      authenticationTag: hmac(payload, secret)
    };
  }

  async signHealth(health: BridgeHealth): Promise<SignedEnvelope | undefined> {
    const secret = await this.loadSecret();
    if (!secret) {
      // Unsigned health envelope: AURA can see the extension is installed but
      // will not trust the payload. It is still useful for diagnostics.
      return {
        payload: {
          protocolVersion: ProtocolVersion,
          extensionID: this.extensionID,
          nonce: crypto.randomBytes(16).toString('hex'),
          issuedAt: new Date().toISOString(),
          expiresAt: new Date(Date.now() + 30_000).toISOString(),
          snapshot: {
            editor: undefined,
            terminal: undefined,
            diagnostics: [],
            tasks: [],
            tests: [],
            terminals: [],
            timestamp: new Date().toISOString(),
            health
          }
        },
        authenticationTag: ''
      };
    }
    const nonce = crypto.randomBytes(16).toString('hex');
    const issuedAt = new Date();
    const expiresAt = new Date(issuedAt.getTime() + 30_000);
    const snapshot: BridgeSnapshot = {
      editor: undefined,
      terminal: undefined,
      diagnostics: [],
      tasks: [],
      tests: [],
      terminals: [],
      timestamp: new Date().toISOString(),
      health
    };
    const payload = {
      protocolVersion: ProtocolVersion,
      extensionID: this.extensionID,
      nonce,
      issuedAt: issuedAt.toISOString(),
      expiresAt: expiresAt.toISOString(),
      snapshot
    };
    return { payload, authenticationTag: hmac(payload, secret) };
  }

  async validateCommand(data: Buffer): Promise<BridgeCommand | undefined> {
    const secret = await this.loadSecret();
    if (!secret) return undefined;
    const envelope = JSON.parse(data.toString('utf8'));
    const expectedTag = hmac(envelope.payload, secret);
    if (envelope.authenticationTag !== expectedTag) {
      this.logger.log('command envelope authentication failed');
      return undefined;
    }
    if (envelope.payload.extensionID !== this.extensionID) {
      this.logger.log('command envelope extension ID mismatch');
      return undefined;
    }
    const now = Date.now();
    const issuedAt = new Date(envelope.payload.issuedAt).getTime();
    const expiresAt = new Date(envelope.payload.expiresAt).getTime();
    if (issuedAt > now + 5000 || expiresAt <= now) {
      this.logger.log('command envelope rejected for freshness');
      return undefined;
    }
    return envelope.payload.command as BridgeCommand;
  }

  async signResponse(
    requestNonce: string,
    result: BridgeCommandResult
  ): Promise<SignedEnvelope | undefined> {
    const secret = await this.loadSecret();
    if (!secret) return undefined;
    const nonce = crypto.randomBytes(16).toString('hex');
    const issuedAt = new Date();
    const expiresAt = new Date(issuedAt.getTime() + 30_000);
    const payload = {
      protocolVersion: ProtocolVersion,
      extensionID: this.extensionID,
      requestNonce,
      nonce,
      issuedAt: issuedAt.toISOString(),
      expiresAt: expiresAt.toISOString(),
      result
    };
    return { payload, authenticationTag: hmac(payload, secret) };
  }
}

function hmac(payload: unknown, secret: Buffer): string {
  const canon = JSON.stringify(payload, Object.keys(payload as object).sort());
  return crypto.createHmac('sha256', secret).update(canon).digest('base64');
}
