package com.makeitquick.customer;

import com.makeitquick.security.UserAccount;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "saved_addresses")
public class SavedAddress {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(optional = false) private UserAccount customer;
    @Column(nullable = false) private String label;
    @Column(nullable = false, length = 1000) private String address;
    @Column(nullable = false, length = 6) private String pinCode;
    protected SavedAddress() {}
    SavedAddress(UserAccount customer, String label, String address, String pinCode) { this.customer=customer; this.label=label; this.address=address; this.pinCode=pinCode; }
    public Long getId(){return id;} public UserAccount getCustomer(){return customer;} public String getLabel(){return label;} public String getAddress(){return address;} public String getPinCode(){return pinCode;}
}
