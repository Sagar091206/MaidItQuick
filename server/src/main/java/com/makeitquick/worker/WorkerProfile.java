package com.makeitquick.worker;
import com.makeitquick.operations.AvailabilityStatus; import com.makeitquick.security.UserAccount; import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="worker_profiles")
public class WorkerProfile {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @OneToOne(optional=false) private UserAccount user;
 @Enumerated(EnumType.STRING) private VerificationStatus kycStatus=VerificationStatus.NOT_SUBMITTED;
 @Enumerated(EnumType.STRING) private VerificationStatus backgroundCheckStatus=VerificationStatus.NOT_SUBMITTED;
 @Enumerated(EnumType.STRING) @Column(nullable=false) private AvailabilityStatus availability=AvailabilityStatus.OFFLINE;
 private String identityDocumentRef; private String bankAccountLast4; private String bankIfsc; private boolean payoutDetailsVerified;
 private Double lastLatitude; private Double lastLongitude; private Instant locationUpdatedAt;
 protected WorkerProfile(){} public WorkerProfile(UserAccount u){user=u;}
 public Long getId(){return id;} public UserAccount getUser(){return user;} public VerificationStatus getKycStatus(){return kycStatus;} public VerificationStatus getBackgroundCheckStatus(){return backgroundCheckStatus;} public AvailabilityStatus getAvailability(){return availability;} public boolean isPayoutDetailsVerified(){return payoutDetailsVerified;}
 public void submitKyc(String ref){identityDocumentRef=ref;kycStatus=VerificationStatus.PENDING; backgroundCheckStatus=VerificationStatus.PENDING;}
 public void setPayout(String last4,String ifsc){bankAccountLast4=last4;bankIfsc=ifsc;payoutDetailsVerified=false;}
 public void approve(){kycStatus=VerificationStatus.APPROVED;backgroundCheckStatus=VerificationStatus.APPROVED;payoutDetailsVerified=true;} public void reject(){kycStatus=VerificationStatus.REJECTED; backgroundCheckStatus=VerificationStatus.REJECTED;}
 public void setAvailability(AvailabilityStatus value){availability=value;}
 public Double getLastLatitude(){return lastLatitude;} public Double getLastLongitude(){return lastLongitude;} public Instant getLocationUpdatedAt(){return locationUpdatedAt;}
 public void updateLocation(double latitude,double longitude){lastLatitude=latitude;lastLongitude=longitude;locationUpdatedAt=Instant.now();}
}
