package com.maiditquick.admin.admin;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;
public interface AdminRepository extends JpaRepository<Admin, Long> {
  Optional<Admin> findByEmailIgnoreCase(String email);
  boolean existsByRole(AdminRole role);
  Page<Admin> findByEmailIgnoreCaseContainingOrDisplayNameIgnoreCaseContaining(String email, String name, Pageable pageable);
  long countByRoleCodeAndEnabledTrue(String roleCode);
}
