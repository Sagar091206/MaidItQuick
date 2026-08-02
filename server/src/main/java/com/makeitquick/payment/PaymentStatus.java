package com.makeitquick.payment;

/**
 * Payment lifecycle. UNPAID lives on the booking (no payment attempted yet);
 * PENDING / PAID / FAILED / REFUNDED live on the payment ledger records.
 */
public enum PaymentStatus { UNPAID, PENDING, PAID, FAILED, REFUNDED }
