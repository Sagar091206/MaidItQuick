package com.makeitquick.notification;

import com.makeitquick.security.UserAccount;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

interface NotificationRepository extends JpaRepository<AppNotification, Long> {
    List<AppNotification> findByRecipientOrderByCreatedAtDesc(UserAccount recipient);
    Optional<AppNotification> findByIdAndRecipient(Long id, UserAccount recipient);
}
