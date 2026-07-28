package com.makeitquick.catalog;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

interface ServiceItemRepository extends JpaRepository<ServiceItem, Long> {
    List<ServiceItem> findByEnabledTrueOrderByNameAsc();
    Optional<ServiceItem> findByNameIgnoreCase(String name);
}
