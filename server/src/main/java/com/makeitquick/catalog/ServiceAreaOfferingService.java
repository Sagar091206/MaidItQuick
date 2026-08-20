package com.makeitquick.catalog;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
@Service
public class ServiceAreaOfferingService {
 private final ServiceAreaOfferingRepository offerings;
 ServiceAreaOfferingService(ServiceAreaOfferingRepository offerings){this.offerings=offerings;}
 public ServiceAreaOffering require(String pin,String service){return offerings.findByServiceAreaPinCodeAndServiceNameIgnoreCase(pin,service)
   .filter(ServiceAreaOffering::isEnabled).filter(o->o.getServiceArea().isEnabled()).filter(o->o.getService().isEnabled())
   .orElseThrow(()->new ResponseStatusException(HttpStatus.CONFLICT,service+" is not available in PIN "+pin));}
}
