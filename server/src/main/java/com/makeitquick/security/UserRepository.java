package com.makeitquick.security;
import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
public interface UserRepository extends JpaRepository<UserAccount,Long>{Optional<UserAccount> findByEmailIgnoreCase(String email); List<UserAccount> findAllByOrderByIdDesc();}
