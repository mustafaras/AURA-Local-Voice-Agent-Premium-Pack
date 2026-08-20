export class Logger {
  private channel: { appendLine: (value: string) => void };

  constructor(channel: { appendLine: (value: string) => void }) {
    this.channel = channel;
  }

  log(message: string): void {
    this.channel.appendLine(`[${new Date().toISOString()}] ${message}`);
  }
}
