package com.makeitquick.security;
import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="sessions")
public class Session {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @Column(nullable=false,unique=true,length=96) private String token;
 @ManyToOne(optional=false) private UserAccount user;
 @Column(nullable=false) private Instant expiresAt;
 protected Session(){} public Session(String token,UserAccount user,Instant expiresAt){this.token=token;this.user=user;this.expiresAt=expiresAt;}
 public String getToken(){return token;} public UserAccount getUser(){return user;} public boolean valid(){return expiresAt.isAfter(Instant.now())&&user.isEnabled();}
}
