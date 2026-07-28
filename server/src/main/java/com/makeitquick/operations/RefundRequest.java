package com.makeitquick.operations;
import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="refund_requests")
public class RefundRequest {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @Column(nullable=false) private String bookingReference;
 @Column(nullable=false) private String reason;
 @Column(nullable=false) private int amountPaise;
 @Enumerated(EnumType.STRING) @Column(nullable=false) private RefundStatus status=RefundStatus.REQUESTED;
 @Column(nullable=false,updatable=false) private Instant createdAt=Instant.now();
 protected RefundRequest(){} public RefundRequest(String ref,String reason,int amount){bookingReference=ref;this.reason=reason;amountPaise=amount;}
 public void approve(){status=RefundStatus.APPROVED;} public void reject(){status=RefundStatus.REJECTED;} public void complete(){status=RefundStatus.COMPLETED;}
 public Long getId(){return id;} public String getBookingReference(){return bookingReference;} public String getReason(){return reason;} public int getAmountPaise(){return amountPaise;} public RefundStatus getStatus(){return status;}
}
