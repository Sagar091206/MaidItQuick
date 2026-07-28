package com.makeitquick.operations;

import org.springframework.stereotype.Service;

@Service
public class ServiceAreaService {
    private final ServiceAreaRepository areas;

    ServiceAreaService(ServiceAreaRepository areas) {
        this.areas = areas;
    }

    public boolean acceptsBookings(String pinCode) {
        return areas.findByPinCode(pinCode).map(ServiceArea::isEnabled).orElse(false);
    }
}
