package com.makeitquick.support;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

interface SupportMessageRepository extends JpaRepository<SupportMessage, Long> {
    List<SupportMessage> findByTicket_IdOrderByCreatedAtAsc(Long ticketId);
}
