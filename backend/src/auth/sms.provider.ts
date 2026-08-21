/**
 * SMS abstraction. The app needs OTP delivery + incoming-batch alerts.
 * In dev we use a mock that logs to console and stores the last code so
 * tests and manual flows can read it. Swap in Dialog/Airtel/Twilio later
 * by providing a different SMS_PROVIDER implementation.
 */
export const SMS_PROVIDER = Symbol("SMS_PROVIDER");

export interface SmsMessage {
  to: string; // E.164
  body: string;
}

export interface SmsProvider {
  send(message: SmsMessage): Promise<void>;
}
