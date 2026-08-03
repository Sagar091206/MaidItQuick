package com.makeitquick.customer;

import com.makeitquick.security.UserAccount;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SavedAddressRepository extends JpaRepository<SavedAddress, Long> {
    List<SavedAddress> findByCustomerOrderByIdDesc(UserAccount customer);
    Optional<SavedAddress> findByIdAndCustomer(Long id, UserAccount customer);
    Optional<SavedAddress> findByCustomerAndDefaultAddressTrue(UserAccount customer);
    long countByCustomer(UserAccount customer);
}
