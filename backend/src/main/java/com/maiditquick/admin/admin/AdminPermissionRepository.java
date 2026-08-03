package com.maiditquick.admin.admin;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;
public interface AdminPermissionRepository extends JpaRepository<AdminPermission, Long> {
  Optional<AdminPermission> findByCode(String code);
  List<AdminPermission> findByCodeIn(Collection<String> codes);
}
