package com.makeitquick.security;
import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="users")
public class UserAccount {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @Column(nullable=false) private String name;
 @Column(nullable=false,unique=true) private String email;
 @Column(nullable=false) private String passwordHash;
 @Column(unique=true) private String phone;
 @Enumerated(EnumType.STRING) @Column(nullable=false) private Role role;
 @Column(nullable=false) private boolean enabled=true;
 @Column(nullable=false) private boolean emailNotifications=true;
 @Column(nullable=false,updatable=false) private Instant createdAt=Instant.now();
 protected UserAccount(){} public UserAccount(String n,String e,String p,Role r){name=n;email=e;passwordHash=p;role=r;}
 public UserAccount(String n,String e,String p,String ph,Role r){name=n;email=e;passwordHash=p;phone=ph;role=r;}
 public Long getId(){return id;} public String getName(){return name;} public String getEmail(){return email;} public String getPasswordHash(){return passwordHash;} public String getPhone(){return phone;} public Role getRole(){return role;} public boolean isEnabled(){return enabled;} public boolean isEmailNotifications(){return emailNotifications;}
 public void setPasswordHash(String value){passwordHash=value;} public void disable(){enabled=false;}
 public void setEmailNotifications(boolean value){emailNotifications=value;}
}
