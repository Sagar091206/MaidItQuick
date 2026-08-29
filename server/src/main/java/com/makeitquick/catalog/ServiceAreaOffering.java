package com.makeitquick.catalog;

import com.makeitquick.operations.ServiceArea;
import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "service_area_offerings", uniqueConstraints =
        @UniqueConstraint(name = "uk_area_service", columnNames = {"service_area_id", "service_id"}))
public class ServiceAreaOffering {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(optional = false) @JoinColumn(name = "service_area_id") private ServiceArea serviceArea;
    @ManyToOne(optional = false) @JoinColumn(name = "service_id") private ServiceItem service;
    @Column(nullable = false) private int pricePaise;
    @Column(nullable = false) private boolean enabled = true;
    @Column(nullable = false, updatable = false) private Instant createdAt = Instant.now();
    @Column(nullable = false) private Instant updatedAt = Instant.now();
    protected ServiceAreaOffering() {}
    public ServiceAreaOffering(ServiceArea area, ServiceItem service, int pricePaise) { this.serviceArea=area; this.service=service; this.pricePaise=pricePaise; }
    public Long getId(){return id;} public ServiceArea getServiceArea(){return serviceArea;} public ServiceItem getService(){return service;}
    public int getPricePaise(){return pricePaise;} public boolean isEnabled(){return enabled;} public Instant getCreatedAt(){return createdAt;} public Instant getUpdatedAt(){return updatedAt;}
    public void update(int pricePaise, boolean enabled){this.pricePaise=pricePaise;this.enabled=enabled;this.updatedAt=Instant.now();}
}
