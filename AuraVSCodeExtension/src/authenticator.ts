import * as crypto from 'crypto';
import * as vscode from 'vscode';
import { Logger } from './logger';
import { BridgeSnapshot, BridgeCommand, BridgeCommandResult, BridgeHealth, SignedEnvelope, ProtocolVersion } from './protocol';

/** A validated command together with the request nonce its response must echo. */
export interface ValidatedCommand {
  command: BridgeCommand;
  nonce: string;
}

const envelopeLifetimeMs = 30_000;
const clockSkewMs = 5_000;

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

  /** Common envelope metadata shared by every signed message. */
  private meta(): { protocolVersion: number; extensionID: string; nonce: string; issuedAt: string; expiresAt: string } {
    const issuedAt = new Date();
    return {
      protocolVersion: ProtocolVersion,
      extensionID: this.extensionID,
      nonce: crypto.randomBytes(16).toString('hex'),
      issuedAt: issuedAt.toISOString(),
      expiresAt: new Date(issuedAt.getTime() + envelopeLifetimeMs).toISOString()
    };
  }

  /**
   * Serializes the payload exactly once and authenticates those bytes. The
   * receiver verifies the same transmitted string, so neither side depends on
   * the other's key ordering, string escaping, date precision, or field set.
   */
  private seal(payload: unknown, secret: Buffer): SignedEnvelope {
    const payloadText = JSON.stringify(payload);
    return { payload: payloadText, authenticationTag: hmac(payloadText, secret) };
  }

  async signSnapshot(snapshot: BridgeSnapshot): Promise<SignedEnvelope | undefined> {
    const secret = await this.loadSecret();
    if (!secret) return undefined;
    return this.seal({ ...this.meta(), snapshot }, secret);
  }

  async signHealth(health: BridgeHealth): Promise<SignedEnvelope | undefined> {
    const snapshot: BridgeSnapshot = {
      diagnostics: [],
      timestamp: new Date().toISOString(),
      health
    };
    const payload = { ...this.meta(), snapshot };
    const secret = await this.loadSecret();
    if (!secret) {
      // Unsigned health envelope: AURA can see the extension is installed but
      // will reject the payload as unauthenticated. Useful for diagnostics only.
      return { payload: JSON.stringify(payload), authenticationTag: '' };
    }
    return this.seal(payload, secret);
  }

  async validateCommand(data: Buffer): Promise<ValidatedCommand | undefined> {
    const secret = await this.loadSecret();
    if (!secret) return undefined;

    let envelope: { payload?: unknown; authenticationTag?: unknown };
    try {
      envelope = JSON.parse(data.toString('utf8'));
    } catch (err) {
      this.logger.log('command envelope is not valid JSON');
      return undefined;
    }

    const payloadText = envelope.payload;
    if (typeof payloadText !== 'string' || typeof envelope.authenticationTag !== 'string') {
      this.logger.log('command envelope is malformed');
      return undefined;
    }

    // Authenticate the received bytes before parsing anything inside them.
    if (!timingSafeEqual(envelope.authenticationTag, hmac(payloadText, secret))) {
      this.logger.log('command envelope authentication failed');
      return undefined;
    }

    let payload: {
      protocolVersion?: number;
      extensionID?: string;
      nonce?: string;
      issuedAt?: string;
      expiresAt?: string;
      command?: BridgeCommand;
    };
    try {
      payload = JSON.parse(payloadText);
    } catch (err) {
      this.logger.log('command payload is not valid JSON');
      return undefined;
    }

    if (payload.protocolVersion !== ProtocolVersion) {
      this.logger.log(`command envelope protocol mismatch: ${payload.protocolVersion}`);
      return undefined;
    }
    if (payload.extensionID !== this.extensionID) {
      this.logger.log('command envelope extension ID mismatch');
      return undefined;
    }
    const now = Date.now();
    const issuedAt = new Date(payload.issuedAt ?? '').getTime();
    const expiresAt = new Date(payload.expiresAt ?? '').getTime();
    if (!Number.isFinite(issuedAt) || !Number.isFinite(expiresAt)) {
      this.logger.log('command envelope has invalid timestamps');
      return undefined;
    }
    if (issuedAt > now + clockSkewMs || expiresAt <= now) {
      this.logger.log('command envelope rejected for freshness');
      return undefined;
    }
    if (!payload.command || typeof payload.nonce !== 'string' || payload.nonce.length === 0) {
      this.logger.log('command envelope is missing a command or nonce');
      return undefined;
    }
    // The nonce travels back with the response so AURA can bind the two.
    return { command: payload.command, nonce: payload.nonce };
  }

  async signResponse(
    requestNonce: string,
    result: BridgeCommandResult
  ): Promise<SignedEnvelope | undefined> {
    const secret = await this.loadSecret();
    if (!secret) return undefined;
    return this.seal({ ...this.meta(), requestNonce, result }, secret);
  }
}

function hmac(payloadText: string, secret: Buffer): string {
  return crypto.createHmac('sha256', secret).update(payloadText, 'utf8').digest('base64');
}

/** Compares tags without leaking match position through timing. */
function timingSafeEqual(lhs: string, rhs: string): boolean {
  const left = Buffer.from(lhs, 'utf8');
  const right = Buffer.from(rhs, 'utf8');
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}
