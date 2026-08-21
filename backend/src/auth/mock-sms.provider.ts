import { Injectable, Logger } from "@nestjs/common";
import { SmsMessage, SmsProvider } from "./sms.provider";

/**
 * Dev/test SMS provider. Logs the message and keeps the most recent code per
 * mobile in memory so flows can be exercised without a real gateway.
 */
@Injectable()
export class MockSmsProvider implements SmsProvider {
  private readonly logger = new Logger("MockSms");
  private readonly lastCodes = new Map<string, string>();

  async send(message: SmsMessage): Promise<void> {
    const codeMatch = message.body.match(/\b(\d{6})\b/);
    if (codeMatch) {
      this.lastCodes.set(message.to, codeMatch[1]);
    }
    this.logger.log(`[SMS -> ${message.to}] ${message.body}`);
  }

  /** Test/dev helper: read the last OTP issued for a mobile. */
  lastCodeFor(mobile: string): string | undefined {
    return this.lastCodes.get(mobile);
  }
}
