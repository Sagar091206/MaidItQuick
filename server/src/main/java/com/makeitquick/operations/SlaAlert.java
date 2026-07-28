package com.makeitquick.operations;
import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="sla_alerts")
public class SlaAlert {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @Column(nullable=false) private String bookingReference;
 @Enumerated(EnumType.STRING) @Column(nullable=false) private AlertSeverity severity;
 @Column(nullable=false) private String message;
 @Column(nullable=false) private boolean resolved=false;
 @Column(nullable=false,updatable=false) private Instant createdAt=Instant.now();
 protected SlaAlert(){} public SlaAlert(String ref,AlertSeverity s,String message){bookingReference=ref;severity=s;this.message=message;}
 public void resolve(){resolved=true;}
 public Long getId(){return id;} public String getBookingReference(){return bookingReference;} public AlertSeverity getSeverity(){return severity;} public String getMessage(){return message;} public boolean isResolved(){return resolved;}
}
