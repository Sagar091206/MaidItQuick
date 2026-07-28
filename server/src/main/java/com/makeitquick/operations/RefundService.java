package com.makeitquick.operations;

import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@Service
public class RefundService {
    private final RefundRequestRepository refunds;

    RefundService(RefundRequestRepository refunds) {
        this.refunds = refunds;
    }

    public RefundRequest request(String bookingReference, String reason, int amountPaise) {
        if (refunds.existsByBookingReference(bookingReference)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "A refund request already exists for this booking");
        }
        return refunds.save(new RefundRequest(bookingReference, reason, amountPaise));
    }
}
