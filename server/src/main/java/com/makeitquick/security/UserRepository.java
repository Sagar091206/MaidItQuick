package com.makeitquick.security;
import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
public interface UserRepository extends JpaRepository<UserAccount,Long>{Optional<UserAccount> findByEmailIgnoreCase(String email); Optional<UserAccount> findByPhoneAndRole(String phone,Role role); List<UserAccount> findAllByOrderByIdDesc();}
