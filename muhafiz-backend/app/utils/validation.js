/**
 * Clean a phone number by stripping spaces, dashes, parentheses, and leading '+' or '00'.
 */
function cleanPhone(phone) {
  if (typeof phone !== "string" && typeof phone !== "number") return "";
  let cleaned = String(phone).replace(/[\s\-\(\)]/g, "");
  if (cleaned.startsWith("+")) cleaned = cleaned.slice(1);
  if (cleaned.startsWith("00")) cleaned = cleaned.slice(2);
  return cleaned;
}

/**
 * Validate a phone number. Must be a string (or coercible), and cleaned version must be 10-15 digits.
 */
function validatePhone(phone) {
  const cleaned = cleanPhone(phone);
  const phoneRegex = /^[1-9]\d{9,14}$/; // 10 to 15 digits, non-zero start
  return phoneRegex.test(cleaned);
}

/**
 * Validate an OTP. Must be exactly 6 digits.
 */
function validateOtp(otp) {
  if (typeof otp !== "string" && typeof otp !== "number") return false;
  const otpStr = String(otp).trim();
  return /^\d{6}$/.test(otpStr);
}

/**
 * Validate a message. Must be a non-empty string and under 1000 characters.
 */
function validateMessage(message) {
  if (typeof message !== "string") return false;
  const trimmed = message.trim();
  return trimmed.length > 0 && trimmed.length <= 1000;
}

/**
 * Validate GPS coordinates (latitude and longitude).
 */
function validateCoordinates(lat, lng) {
  if (lat === undefined || lat === null || lng === undefined || lng === null) {
    return true; // Optional fields are considered valid if missing
  }
  const latitude = Number(lat);
  const longitude = Number(lng);
  if (isNaN(latitude) || isNaN(longitude)) return false;
  return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
}

/**
 * Validate trusted contacts list. Must be a non-empty array of valid phone numbers.
 */
function validateTrustees(trustees) {
  if (!Array.isArray(trustees) || trustees.length === 0) return false;
  return trustees.every(phone => validatePhone(phone));
}

module.exports = {
  cleanPhone,
  validatePhone,
  validateOtp,
  validateMessage,
  validateCoordinates,
  validateTrustees
};
