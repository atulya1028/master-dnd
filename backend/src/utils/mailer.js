const nodemailer = require('nodemailer');

const createTransporter = () => {
  const host = (process.env.SMTP_HOST || '').trim();
  const user = (process.env.SMTP_USER || '').trim();
  const pass = (process.env.SMTP_PASS || '').trim();

  if (!host || !user || !pass) {
    return null;
  }

  const port = parseInt(process.env.SMTP_PORT || '587', 10);
  const secure = process.env.SMTP_SECURE === 'true' || port === 465;

  return nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
    tls: { rejectUnauthorized: false },
  });
};

const sendOtpEmail = async (toEmail, otpCode) => {
  console.log('----------------------------------------------------');
  console.log(`[EMAIL OTP SERVICE - NODEMAILER]`);
  console.log(`  To: ${toEmail}`);
  console.log(`  OTP Code: ${otpCode}`);
  console.log(`  Subject: Your Master DND Verification Code`);
  console.log('----------------------------------------------------');

  const transporter = createTransporter();
  if (!transporter) {
    console.warn('[Nodemailer] SMTP settings not fully configured in .env. Logged to console.');
    return { success: true, delivered: false, simulated: true };
  }

  try {
    const fromAddress = process.env.SMTP_FROM || `"Master DND" <${process.env.SMTP_USER}>`;
    const info = await transporter.sendMail({
      from: fromAddress,
      to: toEmail,
      subject: `Your Master DND Verification Code: ${otpCode}`,
      priority: 'high',
      headers: {
        'X-Priority': '1 (Highest)',
        'X-MSMail-Priority': 'High',
        'Importance': 'High',
      },
      text: `Your Master DND verification code is ${otpCode}. It expires in 5 minutes.`,
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px 24px; border: 1px solid #E1E4F0; border-radius: 16px; background: #FFFFFF;">
          <div style="text-align: center; margin-bottom: 24px;">
            <div style="display: inline-block; width: 64px; height: 64px; background: #E8EBFA; border-radius: 50%; line-height: 64px; font-size: 28px;">🌙</div>
            <h2 style="color: #14172F; margin: 16px 0 4px 0; font-size: 22px; font-weight: 800;">Master DND</h2>
            <p style="color: #5B6085; font-size: 14px; margin: 0;">One control center for every way a phone stays quiet.</p>
          </div>
          <div style="background: #F6F7FB; border: 1px solid #E1E4F0; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
            <p style="color: #5B6085; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 10px 0; font-weight: 700;">Verification Code</p>
            <div style="font-size: 36px; font-weight: 900; letter-spacing: 10px; color: #3F51B5; font-family: monospace;">${otpCode}</div>
            <p style="color: #5B6085; font-size: 13px; margin: 12px 0 0 0;">Expires in 5 minutes. Do not share this code with anyone.</p>
          </div>
          <p style="color: #5B6085; font-size: 12px; text-align: center; margin: 0;">If you didn't request this verification code, you can safely ignore this email.</p>
        </div>
      `,
    });

    console.log(`[Nodemailer] Email successfully delivered to ${toEmail}. Message ID: ${info.messageId}`);
    return { success: true, delivered: true, messageId: info.messageId };
  } catch (err) {
    console.error(`[Nodemailer] Failed to send email to ${toEmail}:`, err.message);
    return { success: true, delivered: false, error: err.message };
  }
};

module.exports = {
  createTransporter,
  sendOtpEmail,
};
