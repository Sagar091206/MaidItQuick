package com.makeitquick.operations;
import jakarta.persistence.*;
@Entity @Table(name="service_areas")
public class ServiceArea {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @Column(nullable=false,unique=true,length=6) private String pinCode;
 @Column(nullable=false) private String locality;
 @Column(nullable=false) private boolean enabled=true;
 protected ServiceArea(){} public ServiceArea(String pin,String locality){this.pinCode=pin;this.locality=locality;}
 public Long getId(){return id;} public String getPinCode(){return pinCode;} public String getLocality(){return locality;} public boolean isEnabled(){return enabled;} public void setEnabled(boolean value){enabled=value;}
}
