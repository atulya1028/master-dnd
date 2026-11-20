/**
 * OTP Generation and delivery helper.
 * Pluggable with Twilio, AWS SNS, or Firebase for production SMS delivery.
 */

const generateOtp = () => {
  // Generate a random 6-digit number string: 100000 - 999999
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  return code;
};

const sendSmsOtp = async (phone, otp) => {
  // Production integration point (e.g. Twilio client):
  // if (process.env.TWILIO_ACCOUNT_SID) { ... }
  
  // Console logging for local development and real-time verification
  console.log('----------------------------------------------------');
  console.log(`[SMS GATEWAY SIMULATOR]`);
  console.log(`  To: ${phone}`);
  console.log(`  OTP Code: ${otp}`);
  console.log(`  Message: Your Master DND verification code is ${otp}. Valid for 5 minutes.`);
  console.log('----------------------------------------------------');

  return { success: true };
};

module.exports = {
  generateOtp,
  sendSmsOtp,
};
