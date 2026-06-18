/**
 * Formats a phone number as (XXX) XXX-XXXX
 * @param {string} value - Raw phone number input
 * @returns {string} Formatted phone number
 */
export function formatPhoneNumber(value) {
  if (!value) return value;

  // Remove all non-numeric characters
  const phoneNumber = value.replace(/[^\d]/g, '');

  // Format based on length
  const phoneNumberLength = phoneNumber.length;

  if (phoneNumberLength < 4) {
    return phoneNumber;
  }

  if (phoneNumberLength < 7) {
    return `(${phoneNumber.slice(0, 3)}) ${phoneNumber.slice(3)}`;
  }

  return `(${phoneNumber.slice(0, 3)}) ${phoneNumber.slice(3, 6)}-${phoneNumber.slice(6, 10)}`;
}

/**
 * Strips all formatting from a phone number, returning just digits
 * @param {string} value - Formatted phone number
 * @returns {string} Phone number with only digits
 */
export function stripPhoneFormatting(value) {
  if (!value) return value;
  return value.replace(/[^\d]/g, '');
}

/**
 * Validates a phone number (US format)
 * @param {string} value - Phone number to validate
 * @returns {boolean} Whether the phone number is valid
 */
export function isValidPhoneNumber(value) {
  if (!value) return false;
  const digits = stripPhoneFormatting(value);
  return digits.length === 10;
}
