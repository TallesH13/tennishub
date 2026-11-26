import { randomInt } from 'node:crypto';

// D06: sem 0, O, 1 e I, que se confundem ao ler ou ditar o código.
export const BOOKING_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const BOOKING_CODE_LENGTH = 8;

export type BookingCodeGenerator = () => string;

export const generateBookingCode: BookingCodeGenerator = () => {
  let code = '';
  for (let i = 0; i < BOOKING_CODE_LENGTH; i++) {
    code += BOOKING_CODE_ALPHABET[randomInt(BOOKING_CODE_ALPHABET.length)];
  }
  return code;
};
