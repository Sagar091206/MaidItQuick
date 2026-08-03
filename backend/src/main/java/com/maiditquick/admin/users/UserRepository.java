package com.maiditquick.admin.users;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, Long> {
  boolean existsByEmailIgnoreCase(String email);
  boolean existsByEmailIgnoreCaseAndIdNot(String email, Long id);
  Page<User> findByEmailIgnoreCaseContainingOrNameIgnoreCaseContaining(String email, String name, Pageable pageable);
}
