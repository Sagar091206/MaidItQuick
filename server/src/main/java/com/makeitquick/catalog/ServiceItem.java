package com.makeitquick.catalog;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "service_catalog")
public class ServiceItem {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(nullable = false, unique = true, length = 120) private String name;
    @Column(nullable = false) private int pricePaise;
    @Column(nullable = false) private boolean enabled = true;
    protected ServiceItem() {}
    ServiceItem(String name, int pricePaise) { this.name = name; this.pricePaise = pricePaise; }
    public Long getId() { return id; }
    public String getName() { return name; }
    public int getPricePaise() { return pricePaise; }
    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
}
