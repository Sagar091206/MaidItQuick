package com.maiditquick.admin.admin;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;
public interface AdminRoleRepository extends JpaRepository<AdminRole, Long> { Optional<AdminRole> findByCode(String code); }
