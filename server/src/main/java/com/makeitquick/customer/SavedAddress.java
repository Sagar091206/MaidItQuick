package com.makeitquick.customer;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.makeitquick.security.UserAccount;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Entity
@Table(name = "saved_addresses")
public class SavedAddress {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(optional = false)
    @JsonIgnoreProperties({"passwordHash", "enabled", "emailNotifications", "role", "profileImage"})
    private UserAccount customer;
    @Column(nullable = false) private String label;
    @Column(nullable = false, length = 1000) private String address;
    @Column(nullable = false, length = 6) private String pinCode;
    private String houseNumber;
    private String building;
    private String street;
    private String area;
    private String landmark;
    private String city;
    private String state;
    private Double latitude;
    private Double longitude;
    @Column(nullable = false) private boolean defaultAddress;

    protected SavedAddress() {}

    SavedAddress(UserAccount customer, AddressDetails details) {
        this.customer = customer;
        apply(details);
    }

    void apply(AddressDetails details) {
        label = details.label().trim();
        houseNumber = blankToNull(details.houseNumber());
        building = blankToNull(details.building());
        street = blankToNull(details.street());
        area = blankToNull(details.area());
        landmark = blankToNull(details.landmark());
        city = blankToNull(details.city());
        state = blankToNull(details.state());
        pinCode = details.pinCode();
        address = composeAddress();
        latitude = details.latitude();
        longitude = details.longitude();
    }

    public Long getId() { return id; }
    public UserAccount getCustomer() { return customer; }
    public String getLabel() { return label; }
    public String getAddress() { return address; }
    public String getPinCode() { return pinCode; }
    public String getHouseNumber() { return value(houseNumber); }
    public String getBuilding() { return value(building); }
    public String getStreet() { return value(street); }
    public String getArea() { return value(area); }
    public String getLandmark() { return value(landmark); }
    public String getCity() { return value(city); }
    public String getState() { return value(state); }
    public Double getLatitude() { return latitude; }
    public Double getLongitude() { return longitude; }
    public boolean isDefaultAddress() { return defaultAddress; }

    public void setDefaultAddress(boolean value) { defaultAddress = value; }

    private String composeAddress() {
        return Stream.of(houseNumber, building, street, area, landmark, city, state)
                .map(this::value)
                .filter(part -> !part.isBlank())
                .collect(Collectors.joining(", "));
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private String value(String value) {
        return value == null ? "" : value;
    }
}
