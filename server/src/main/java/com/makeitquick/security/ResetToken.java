package com.makeitquick.security;
import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="password_reset_tokens")
public class ResetToken {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @Column(nullable=false,unique=true,length=96) private String token;
 @ManyToOne(optional=false) private UserAccount user;
 @Column(nullable=false) private Instant expiresAt; private boolean used;
 protected ResetToken(){} public ResetToken(String t,UserAccount u,Instant e){token=t;user=u;expiresAt=e;}
 public String getToken(){return token;} public UserAccount getUser(){return user;} public boolean valid(){return !used&&expiresAt.isAfter(Instant.now());} public void use(){used=true;}
}
