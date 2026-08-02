package com.makeitquick.catalog;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ServiceItemRepository extends JpaRepository<ServiceItem, Long> {
    List<ServiceItem> findByEnabledTrueOrderByNameAsc();
    List<ServiceItem> findByEnabledTrueAndNameContainingIgnoreCaseOrderByNameAsc(String name);
    Optional<ServiceItem> findByNameIgnoreCase(String name);
    Optional<ServiceItem> findByIdAndEnabledTrue(Long id);
    Optional<ServiceItem> findByEnabledTrueAndNameIgnoreCase(String name);
}
