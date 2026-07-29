package com.makeitquick.security;

import jakarta.persistence.*; import java.time.Instant;

@Entity @Table(name="partner_otps")
class PartnerOtp {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @Column(nullable=false) private String phone;
 private String name;
 @Enumerated(EnumType.STRING) @Column(nullable=false) private PartnerOtpPurpose purpose;
 @Column(nullable=false) private String otpHash;
 @Column(nullable=false) private Instant expiresAt;
 @Column(nullable=false) private int attempts;
 @Column(nullable=false) private boolean consumed;
 @Column(nullable=false,updatable=false) private Instant createdAt=Instant.now();
 protected PartnerOtp(){}
 PartnerOtp(String ph,String n,PartnerOtpPurpose p,String h,Instant e){phone=ph;name=n;purpose=p;otpHash=h;expiresAt=e;}
 public String getPhone(){return phone;} public String getName(){return name;} public PartnerOtpPurpose getPurpose(){return purpose;} public String getOtpHash(){return otpHash;} public int getAttempts(){return attempts;}
 public boolean valid(){return !consumed&&expiresAt.isAfter(Instant.now())&&attempts<5;}
 public void attempt(){attempts++;}
 public void consume(){consumed=true;}
}
