package com.makeitquick.security;

import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface UserRepository extends JpaRepository<UserAccount, Long> {

    Optional<UserAccount> findByEmailIgnoreCase(String email);

    Optional<UserAccount> findByPhoneAndRole(String phone, Role role);

    List<UserAccount> findAllByOrderByIdDesc();

    Page<UserAccount> findByRole(Role role, Pageable pageable);

    long countByRole(Role role);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCaseAndIdNot(String email, Long id);

    @Query("SELECT u FROM UserAccount u WHERE lower(u.name) LIKE lower(concat('%', :q, '%')) "
            + "OR lower(u.email) LIKE lower(concat('%', :q, '%')) "
            + "OR lower(u.phone) LIKE lower(concat('%', :q, '%'))")
    Page<UserAccount> search(String q, Pageable pageable);

    @Query("SELECT u FROM UserAccount u WHERE u.role = :role AND (lower(u.name) LIKE lower(concat('%', :q, '%')) "
            + "OR lower(u.email) LIKE lower(concat('%', :q, '%')) "
            + "OR lower(u.phone) LIKE lower(concat('%', :q, '%')))")
    Page<UserAccount> searchByRole(Role role, String q, Pageable pageable);
}
