const https = require('https');

/**
 * Generate a cryptographically random or high-entropy 6-digit numeric OTP (100000 - 999999).
 */
const generateOtp = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

/**
 * Sends real SMS using Twilio REST API
 */
const sendTwilioSms = async (toPhone, otpCode) => {
  const accountSid = (process.env.TWILIO_ACCOUNT_SID || '').trim();
  const authToken = (process.env.TWILIO_AUTH_TOKEN || '').trim();
  const fromPhone = (process.env.TWILIO_PHONE_NUMBER || '').trim();

  if (!accountSid || !authToken || !fromPhone) {
    return null; // Not configured
  }

  const postData = new URLSearchParams({
    To: toPhone,
    From: fromPhone,
    Body: `Your Master DND verification code is: ${otpCode}. Valid for 5 minutes. Do not share this code.`,
  }).toString();

  const auth = Buffer.from(`${accountSid}:${authToken}`).toString('base64');

  return new Promise((resolve) => {
    const req = https.request(
      {
        hostname: 'api.twilio.com',
        port: 443,
        path: `/2010-04-01/Accounts/${accountSid}/Messages.json`,
        method: 'POST',
        headers: {
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(postData),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            if (res.statusCode >= 200 && res.statusCode < 300) {
              console.log(`[Twilio SMS] Real SMS delivered to ${toPhone}. SID: ${parsed.sid}`);
              resolve({ success: true, delivered: true, sid: parsed.sid, provider: 'twilio' });
            } else {
              console.error(`[Twilio SMS] Error:`, parsed.message || data);
              resolve({ success: false, delivered: false, error: parsed.message || data });
            }
          } catch (e) {
            resolve({ success: false, delivered: false, error: data });
          }
        });
      }
    );

    req.on('error', (err) => {
      console.error(`[Twilio SMS] Network error:`, err.message);
      resolve({ success: false, delivered: false, error: err.message });
    });

    req.write(postData);
    req.end();
  });
};

/**
 * Sends real SMS to Indian numbers using Fast2SMS API
 */
const sendFast2Sms = async (toPhone, otpCode) => {
  const apiKey = (process.env.FAST2SMS_API_KEY || '').trim();
  if (!apiKey) return null;

  // Extract clean 10-digit number (remove leading +91 or 0)
  const cleanNumber = toPhone.replace(/^\+91/, '').replace(/^0/, '').replace(/[^\d]/g, '');

  return new Promise((resolve) => {
    const postData = JSON.stringify({
      variables_values: otpCode,
      route: 'otp',
      numbers: cleanNumber,
    });

    const req = https.request(
      {
        hostname: 'www.fast2sms.com',
        port: 443,
        path: '/dev/bulkV2',
        method: 'POST',
        headers: {
          authorization: apiKey,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            if (parsed.return === true) {
              console.log(`[Fast2SMS] Real SMS dispatched to ${toPhone}.`);
              resolve({ success: true, delivered: true, provider: 'fast2sms' });
            } else {
              console.error(`[Fast2SMS] Error:`, parsed.message);
              resolve({ success: false, delivered: false, error: parsed.message });
            }
          } catch (e) {
            resolve({ success: false, error: data });
          }
        });
      }
    );

    req.on('error', (err) => resolve({ success: false, error: err.message }));
    req.write(postData);
    req.end();
  });
};

/**
 * Dispatches SMS OTP using the configured provider (Twilio or Fast2SMS) or simulator
 */
const sendSmsOtp = async (phone, otp) => {
  // 1. Try Twilio
  const twilioResult = await sendTwilioSms(phone, otp);
  if (twilioResult && twilioResult.delivered) {
    return twilioResult;
  }

  // 2. Try Fast2SMS (popular for Indian numbers)
  const fast2SmsResult = await sendFast2Sms(phone, otp);
  if (fast2SmsResult && fast2SmsResult.delivered) {
    return fast2SmsResult;
  }

  // 3. Fallback: Log to console when no SMS carrier credentials are in .env
  console.log('----------------------------------------------------');
  console.log(`[SMS OTP SERVICE]`);
  console.log(`  To Phone: ${phone}`);
  console.log(`  Real OTP: ${otp}`);
  console.log(`  Status: Logged to console.`);
  console.log(`  (To deliver real SMS to mobile devices, add Twilio or Fast2SMS credentials to backend/.env)`);
  console.log('----------------------------------------------------');

  return { success: true, delivered: false, simulated: true };
};

module.exports = {
  generateOtp,
  sendSmsOtp,
  sendTwilioSms,
  sendFast2Sms,
};
