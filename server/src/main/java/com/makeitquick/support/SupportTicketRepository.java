package com.makeitquick.support;

import com.makeitquick.security.UserAccount;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

interface SupportTicketRepository extends JpaRepository<SupportTicket, Long> {
    List<SupportTicket> findByRequesterOrderByIdDesc(UserAccount requester);
}
