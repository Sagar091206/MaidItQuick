package com.makeitquick.admin.notifications;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

public interface AdminNotificationRepository extends JpaRepository<Notification, Long> {
  long countByReadFalse();

  @Modifying
  @Transactional
  @Query("UPDATE Notification n SET n.read = true WHERE n.read = false")
  int markAllRead();
}
