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
    @Column(length = 1000) private String description = "";
    @Column(length = 8) private String emoji = "";
    @Column(nullable = false) private int defaultDurationMinutes = 60;
    protected ServiceItem() {}
    ServiceItem(String name, int pricePaise) { this.name = name; this.pricePaise = pricePaise; }
    public Long getId() { return id; }
    public String getName() { return name; }
    public int getPricePaise() { return pricePaise; }
    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getDescription() { return description == null ? "" : description; }
    public void setDescription(String description) { this.description = description == null ? "" : description; }
    public String getEmoji() { return emoji == null ? "" : emoji; }
    public void setEmoji(String emoji) { this.emoji = emoji == null ? "" : emoji; }
    public int getDefaultDurationMinutes() { return defaultDurationMinutes; }
    public void setDefaultDurationMinutes(int defaultDurationMinutes) { this.defaultDurationMinutes = defaultDurationMinutes; }
}
