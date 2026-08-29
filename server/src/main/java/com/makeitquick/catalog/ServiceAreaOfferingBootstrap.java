package com.makeitquick.catalog;
import com.makeitquick.operations.ServiceAreaRepository;
import org.springframework.boot.ApplicationArguments; import org.springframework.boot.ApplicationRunner; import org.springframework.core.annotation.Order; import org.springframework.stereotype.Component;
@Component @Order(100)
class ServiceAreaOfferingBootstrap implements ApplicationRunner {
 private final ServiceAreaOfferingRepository offerings; private final ServiceAreaRepository areas; private final ServiceItemRepository services;
 ServiceAreaOfferingBootstrap(ServiceAreaOfferingRepository o,ServiceAreaRepository a,ServiceItemRepository s){offerings=o;areas=a;services=s;}
 public void run(ApplicationArguments args){for(var area:areas.findAll())for(var service:services.findAll())if(offerings.findByServiceAreaIdAndServiceId(area.getId(),service.getId()).isEmpty())offerings.save(new ServiceAreaOffering(area,service,service.getPricePaise()));}
}
