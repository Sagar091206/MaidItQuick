package com.makeitquick.catalog;
import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;
public interface ServiceAreaOfferingRepository extends JpaRepository<ServiceAreaOffering,Long> {
 Optional<ServiceAreaOffering> findByServiceAreaPinCodeAndServiceNameIgnoreCase(String pinCode,String name);
 Optional<ServiceAreaOffering> findByServiceAreaIdAndServiceId(Long areaId,Long serviceId);
 List<ServiceAreaOffering> findByServiceAreaPinCodeAndEnabledTrueOrderByServiceNameAsc(String pinCode);
 List<ServiceAreaOffering> findByServiceIdOrderByServiceAreaPinCodeAsc(Long serviceId);
}
